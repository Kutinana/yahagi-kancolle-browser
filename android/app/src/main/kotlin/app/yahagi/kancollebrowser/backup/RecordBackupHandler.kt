package app.yahagi.kancollebrowser.backup

import android.app.Activity
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.util.Base64
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.File
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.Executors
import java.util.zip.GZIPInputStream

/** Local Documents SAF bridge. The live document is never overwritten in place. */
class RecordBackupHandler(
    private val activity: Activity,
    private val launch: (Intent, Int) -> Unit,
    private val deleteSavedDocument: (Uri) -> Boolean = {
        DocumentsContract.deleteDocument(activity.contentResolver, it)
    },
) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "app.yahagi.kancollebrowser/record_backup"
        const val DIRECTORY_REQUEST = 2410
        const val IMPORT_REQUEST = 2411
        const val SAVE_REQUEST = 2412
        private const val PREFS = "record_backup_documents"
        private const val MAX_BYTES = 100 * 1024 * 1024
    }

    private val resolver get() = activity.contentResolver
    private val prefs get() = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val worker = Executors.newSingleThreadExecutor()
    private var pickerResult: MethodChannel.Result? = null
    private data class SaveTarget(val token: String, val uri: Uri, @Volatile var verified: Boolean = false)
    @Volatile private var saveTarget: SaveTarget? = null
    private data class ShareTarget(val token: String, val file: File)
    @Volatile private var shareTarget: ShareTarget? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasDirectory" -> result.success(directory() != null)
            "chooseDirectory" -> chooseDirectory(result)
            "pickImport" -> pickImport(result)
            "pickSaveLocation" -> pickSaveLocation(call, result)
            "launchShareFile" -> {
                try {
                    val target = requireShareTarget(call)
                    shareExport(target.file)
                    shareTarget = null
                    result.success(target.file.name)
                } catch (error: Throwable) {
                    result.error("backup_share_failed", error.message ?: "Cannot share backup", null)
                }
            }
            "discardShareFile" -> worker.execute {
                try {
                    val target = requireShareTarget(call)
                    try {
                        require(target.file.parentFile?.deleteRecursively() == true) {
                            "Unable to remove unshared backup"
                        }
                    } finally {
                        shareTarget = null
                    }
                    activity.runOnUiThread { result.success(null) }
                } catch (error: Throwable) {
                    activity.runOnUiThread {
                        result.error("backup_share_failed", error.message ?: "Cannot discard share", null)
                    }
                }
            }
            "completeSavedFile" -> {
                try {
                    val target = requireSaveTarget(call)
                    require(target.verified) { "Saved backup has not been verified" }
                    saveTarget = null
                    result.success(null)
                } catch (error: Throwable) {
                    result.error("backup_save_failed", error.message ?: "Cannot complete save", null)
                }
            }
            "writeSavedFile", "discardSavedFile" -> worker.execute {
                try {
                    val target = requireSaveTarget(call)
                    if (call.method == "writeSavedFile") {
                        val bytes = requireBytes(call)
                        require(bytes.isNotEmpty()) { "Backup is empty" }
                        resolver.openOutputStream(target.uri, "w")?.use { stream ->
                            stream.write(bytes)
                            stream.flush()
                        } ?: error("Unable to save backup")
                        require(readDocument(target.uri).contentEquals(bytes)) {
                            "Saved backup verification failed"
                        }
                        target.verified = true
                    } else {
                        try {
                            require(deleteSavedDocument(target.uri)) {
                                "Unable to remove canceled export"
                            }
                        } finally {
                            // A provider failure must not make every later save picker busy.
                            saveTarget = null
                        }
                    }
                    activity.runOnUiThread { result.success(null) }
                } catch (error: Throwable) {
                    activity.runOnUiThread {
                        result.error("backup_save_failed", error.message ?: "Cannot save backup", null)
                    }
                }
            }
            "readCandidate", "promoteCandidate", "writeLive", "prepareShareFile" -> worker.execute {
                try {
                    val response: Any? = when (call.method) {
                        "readCandidate" -> readCandidate(
                            requireMember(call), requireName(call), requireSlot(call),
                        )
                        "promoteCandidate" -> {
                            promoteCandidate(
                                requireMember(call), requireName(call),
                                requireSlot(call), requireBytes(call),
                            )
                            null
                        }
                        "writeLive" -> {
                            writeLive(requireMember(call), requireName(call), requireBytes(call))
                            null
                        }
                        else -> prepareShareFile(requireName(call), requireBytes(call))
                    }
                    activity.runOnUiThread {
                        try {
                            if (call.method == "prepareShareFile") {
                                val file = response as File
                                if (shareTarget != null) {
                                    file.parentFile?.deleteRecursively()
                                    error("A share is already prepared")
                                }
                                val target = ShareTarget(UUID.randomUUID().toString(), file)
                                shareTarget = target
                                result.success(target.token)
                            } else {
                                result.success(response)
                            }
                        } catch (error: Throwable) {
                            result.error("backup_share_failed", error.message ?: "Cannot share backup", null)
                        }
                    }
                } catch (error: Throwable) {
                    activity.runOnUiThread {
                        result.error("backup_io_failed", error.message ?: "Document I/O failed", null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun requireMember(call: MethodCall): Int =
        (call.argument<Number>("memberId")?.toInt() ?: 0).also {
            require(it > 0) { "Game account is unknown" }
        }

    private fun requireName(call: MethodCall): String =
        (call.argument<String>("name") ?: "").also {
            require(it.endsWith(".yhb") && it.length < 180 &&
                !it.contains('/') && !it.contains('\\')) { "Invalid backup name" }
        }

    private fun requireBytes(call: MethodCall): ByteArray =
        (call.argument<ByteArray>("bytes") ?: error("Missing backup data")).also {
            require(it.size <= MAX_BYTES) { "Backup is too large" }
        }

    private fun requireSlot(call: MethodCall): String =
        (call.argument<String>("slot") ?: "").also {
            require(it == "pending" || it == "main" || it == "previous") {
                "Invalid backup copy"
            }
        }

    private fun chooseDirectory(result: MethodChannel.Result) {
        if (pickerResult != null) {
            result.error("picker_busy", "Document picker is already open", null)
            return
        }
        pickerResult = result
        val initial = DocumentsContract.buildDocumentUri(
            "com.android.externalstorage.documents", "primary:Documents",
        )
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, initial)
            }
        }
        launch(intent, DIRECTORY_REQUEST)
    }

    private fun pickImport(result: MethodChannel.Result) {
        if (pickerResult != null) {
            result.error("picker_busy", "Document picker is already open", null)
            return
        }
        pickerResult = result
        launch(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }, IMPORT_REQUEST)
    }

    private fun pickSaveLocation(call: MethodCall, result: MethodChannel.Result) {
        if (pickerResult != null || saveTarget != null) {
            result.error("picker_busy", "Document picker is already open", null)
            return
        }
        try {
            val name = requireName(call)
            val initial = DocumentsContract.buildDocumentUri(
                "com.android.externalstorage.documents", "primary:Documents",
            )
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/octet-stream"
                putExtra(Intent.EXTRA_TITLE, name)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    putExtra(DocumentsContract.EXTRA_INITIAL_URI, initial)
                }
            }
            pickerResult = result
            launch(intent, SAVE_REQUEST)
        } catch (error: Throwable) {
            pickerResult = null
            result.error("backup_save_failed", error.message ?: "Cannot choose save location", null)
        }
    }

    private fun requireSaveTarget(call: MethodCall): SaveTarget {
        val token = call.argument<String>("token") ?: error("Missing save location")
        return saveTarget?.takeIf { it.token == token }
            ?: error("Save location is no longer available")
    }

    private fun requireShareTarget(call: MethodCall): ShareTarget {
        val token = call.argument<String>("token") ?: error("Missing share file")
        return shareTarget?.takeIf { it.token == token }
            ?: error("Share file is no longer available")
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != DIRECTORY_REQUEST && requestCode != IMPORT_REQUEST &&
            requestCode != SAVE_REQUEST) return false
        val result = pickerResult ?: return true
        pickerResult = null
        val uri = data?.data?.takeIf { resultCode == Activity.RESULT_OK }
        if (uri == null) {
            result.success(if (requestCode == DIRECTORY_REQUEST) false else null)
            return true
        }
        if (requestCode == SAVE_REQUEST) {
            val target = SaveTarget(UUID.randomUUID().toString(), uri)
            saveTarget = target
            result.success(target.token)
            return true
        }
        if (requestCode == DIRECTORY_REQUEST) {
            try {
                val id = DocumentsContract.getTreeDocumentId(uri)
                val path = id.substringAfter(':', "")
                require(uri.authority == "com.android.externalstorage.documents" &&
                    (path == Environment.DIRECTORY_DOCUMENTS ||
                        path.startsWith("${Environment.DIRECTORY_DOCUMENTS}/"))) {
                    "请选择本机文档文件夹或其子文件夹"
                }
                resolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                )
                val previous = directory()
                worker.execute {
                    try {
                        if (previous != null && previous != uri) {
                            migrateBackupDocuments(previous, uri)
                        }
                        // Keep member-to-filename mappings for every account. A folder
                        // change must not strand another account's live backup.
                        require(prefs.edit().putString("tree", uri.toString()).commit()) {
                            "Unable to save backup folder"
                        }
                        activity.runOnUiThread { result.success(true) }
                    } catch (error: Throwable) {
                        activity.runOnUiThread {
                            result.error("backup_migration_failed", error.message, null)
                        }
                    }
                }
            } catch (error: Throwable) {
                result.error("invalid_backup_directory", error.message, null)
            }
            return true
        }
        worker.execute {
            try {
                val bytes = readDocument(uri)
                activity.runOnUiThread { result.success(bytes) }
            } catch (error: Throwable) {
                activity.runOnUiThread {
                    result.error("backup_import_failed", error.message, null)
                }
            }
        }
        return true
    }

    private fun directory(): Uri? {
        val uri = prefs.getString("tree", null)?.let(Uri::parse) ?: return null
        val granted = resolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
        return uri.takeIf { granted }
    }

    private fun tree(): Uri = directory() ?: error("Backup folder is unavailable")

    private fun rootDocument(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))

    private fun readDocument(uri: Uri): ByteArray {
        val input = resolver.openInputStream(uri) ?: error("Unable to read backup")
        return input.use { stream ->
            val output = java.io.ByteArrayOutputStream()
            val chunk = ByteArray(8192)
            while (true) {
                val count = stream.read(chunk)
                if (count < 0) break
                require(output.size() + count <= MAX_BYTES) { "Backup is too large" }
                output.write(chunk, 0, count)
            }
            output.toByteArray()
        }
    }

    private fun backupDocuments(tree: Uri): List<Pair<String, Uri>> {
        val id = DocumentsContract.getTreeDocumentId(tree)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, id)
        val found = mutableListOf<Pair<String, Uri>>()
        (resolver.query(
            children,
            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, OpenableColumns.DISPLAY_NAME),
            null, null, null,
        ) ?: error("Unable to enumerate backup documents")).use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME)
            while (cursor.moveToNext()) {
                val name = cursor.getString(nameColumn)
                if (name.endsWith(".yhb") || name.endsWith(".yhb.previous") ||
                    name.endsWith(".yhb.pending")) {
                    found.add(name to DocumentsContract.buildDocumentUriUsingTree(
                        tree, cursor.getString(idColumn),
                    ))
                }
            }
        }
        return found
    }

    private fun migrateBackupDocuments(from: Uri, to: Uri) {
        // Source documents are read only. A conflicting destination is left
        // untouched and the selected folder is not switched.
        for ((name, source) in backupDocuments(from)) {
            val bytes = readDocument(source)
            val existing = find(to, name)
            if (existing != null) {
                val current = readDocument(existing)
                require(current.contentEquals(bytes)) {
                    "The new folder already contains a different $name"
                }
                continue
            }
            val created = DocumentsContract.createDocument(
                resolver, rootDocument(to), "application/octet-stream", name,
            ) ?: error("Unable to copy $name")
            try {
                requireDocumentName(created, name)
                resolver.openOutputStream(created, "w")?.use { it.write(bytes); it.flush() }
                    ?: error("Unable to copy $name")
                val checked = readDocument(created)
                require(checked.contentEquals(bytes)) {
                    "Copied backup verification failed: $name"
                }
            } catch (error: Throwable) {
                runCatching { DocumentsContract.deleteDocument(resolver, created) }
                throw error
            }
        }
    }

    private fun find(tree: Uri, name: String): Uri? {
        val id = DocumentsContract.getTreeDocumentId(tree)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, id)
        var match: Uri? = null
        (resolver.query(
            children,
            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, OpenableColumns.DISPLAY_NAME),
            null, null, null,
        ) ?: error("Unable to enumerate backup documents")).use { cursor ->
            val idColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            while (cursor.moveToNext()) {
                if (cursor.getString(nameColumn) == name) {
                    require(match == null) { "Duplicate backup document name: $name" }
                    match = DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(idColumn))
                }
            }
        }
        return match
    }

    private fun requireDocumentName(uri: Uri, expected: String) {
        val actual = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (!cursor.moveToFirst()) null else cursor.getString(
                    cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME),
                )
            }
        require(actual == expected) {
            "Backup provider renamed $expected to ${actual ?: "unknown"}"
        }
    }

    private fun archiveMemberId(bytes: ByteArray): Int? = runCatching {
        if (!validEnvelope(bytes)) return@runCatching null
        val compressed = Base64.decode(
            JSONObject(bytes.toString(Charsets.UTF_8)).getString("payload"),
            Base64.DEFAULT,
        )
        val stream = GZIPInputStream(ByteArrayInputStream(compressed))
        val plain = stream.use { input ->
            val output = java.io.ByteArrayOutputStream()
            val chunk = ByteArray(8192)
            while (true) {
                val count = input.read(chunk)
                if (count < 0) break
                output.write(chunk, 0, count)
                require(output.size() <= 250 * 1024 * 1024) { "Backup is too large" }
            }
            output.toByteArray()
        }
        JSONObject(plain.toString(Charsets.UTF_8)).getInt("memberId")
    }.getOrNull()

    private fun liveName(tree: Uri, memberId: Int, suggested: String): String {
        prefs.getString("member.$memberId", null)?.let { return it }
        val stem = suggested.removeSuffix(".yhb")
        for (index in 1..1000) {
            val candidate = if (index == 1) suggested else "$stem ($index).yhb"
            val document = find(tree, candidate) ?: return candidate
            val bytes = readDocument(document)
            val owner = archiveMemberId(bytes) ?: listOf(
                "$candidate.pending", "$candidate.previous",
            ).firstNotNullOfOrNull { fallback ->
                find(tree, fallback)?.let { copy ->
                    archiveMemberId(readDocument(copy))
                }
            } ?: error("Unable to verify existing backup account")
            if (owner == memberId) {
                prefs.edit().putString("member.$memberId", candidate).apply()
                return candidate
            }
        }
        error("Too many backup files with the same name")
    }

    private fun candidateName(name: String, slot: String): String = when (slot) {
        "pending" -> "$name.pending"
        "main" -> name
        "previous" -> "$name.previous"
        else -> error("Invalid backup copy")
    }

    private fun readCandidate(memberId: Int, suggested: String, slot: String): ByteArray? {
        val tree = tree()
        val name = liveName(tree, memberId, suggested)
        val document = find(tree, candidateName(name, slot)) ?: return null
        return readDocument(document)
    }

    private fun promoteCandidate(
        memberId: Int, suggested: String, slot: String, expected: ByteArray,
    ) {
        require(slot != "main") { "Main backup needs no recovery" }
        val tree = tree()
        val name = liveName(tree, memberId, suggested)
        val candidate = find(tree, candidateName(name, slot))
            ?: error("Backup copy vanished during recovery")
        require(readDocument(candidate).contentEquals(expected)) {
            "Backup copy changed during recovery"
        }
        require(archiveMemberId(expected) == memberId) {
            "Backup copy belongs to another account"
        }
        if (slot == "previous") {
            // writeLive keeps previous intact until its new pending copy has
            // been fully written and verified.
            writeLive(memberId, suggested, expected)
            return
        }
        val main = find(tree, name)
        if (main != null && readDocument(main).contentEquals(expected)) {
            require(DocumentsContract.deleteDocument(resolver, candidate)) {
                "Unable to remove redundant pending backup"
            }
            return
        }
        // Never delete or rename the chosen pending copy first. If the app
        // stops between the two renames, pending remains the newest valid copy.
        find(tree, "$name.previous")?.let {
            require(DocumentsContract.deleteDocument(resolver, it)) {
                "Unable to rotate previous backup"
            }
        }
        main?.let {
            val old = DocumentsContract.renameDocument(resolver, it, "$name.previous")
                ?: error("Unable to preserve current backup")
            requireDocumentName(old, "$name.previous")
        }
        val promoted = DocumentsContract.renameDocument(resolver, candidate, name)
            ?: error("Unable to promote pending backup")
        requireDocumentName(promoted, name)
        require(readDocument(promoted).contentEquals(expected)) {
            "Promoted backup verification failed"
        }
        prefs.edit().putString("member.$memberId", name).apply()
    }

    private fun validEnvelope(bytes: ByteArray): Boolean = runCatching {
        if (bytes.size > MAX_BYTES) return@runCatching false
        val envelope = JSONObject(bytes.toString(Charsets.UTF_8))
        if (envelope.optString("format") != "yahagi-record-backup" ||
            envelope.optInt("version") != 1) return@runCatching false
        val compressed = Base64.decode(envelope.getString("payload"), Base64.DEFAULT)
        val digest = MessageDigest.getInstance("SHA-256").digest(compressed)
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }
        digest == envelope.getString("sha256")
    }.getOrDefault(false)

    private fun writeLive(memberId: Int, suggested: String, bytes: ByteArray) {
        val tree = tree()
        val name = liveName(tree, memberId, suggested)
        // Keep a known-good document until the replacement has been written
        // and read back. Recovery can use .previous if the app stops mid-swap.
        find(tree, "$name.pending")?.let {
            require(DocumentsContract.deleteDocument(resolver, it)) {
                "Unable to remove stale pending backup"
            }
        }
        val pending = DocumentsContract.createDocument(
            resolver, rootDocument(tree), "application/octet-stream", "$name.pending",
        ) ?: error("Unable to create pending backup")
        try {
            requireDocumentName(pending, "$name.pending")
            resolver.openOutputStream(pending, "w")?.use { it.write(bytes); it.flush() }
                ?: error("Unable to write pending backup")
            val checked = readDocument(pending)
            require(checked.contentEquals(bytes)) {
                "Pending backup verification failed"
            }
            find(tree, "$name.previous")?.let {
                require(DocumentsContract.deleteDocument(resolver, it)) {
                    "Unable to rotate previous backup"
                }
            }
            find(tree, name)?.let { old ->
                val preserved = DocumentsContract.renameDocument(resolver, old, "$name.previous")
                    ?: error("Unable to preserve previous backup")
                requireDocumentName(preserved, "$name.previous")
            }
            val live = DocumentsContract.renameDocument(resolver, pending, name)
                ?: error("Unable to install live backup")
            requireDocumentName(live, name)
            require(readDocument(live).contentEquals(bytes)) {
                "Installed live backup verification failed"
            }
            prefs.edit().putString("member.$memberId", name).apply()
        } catch (error: Throwable) {
            // Keep pending for recovery if the live document was already moved.
            throw error
        }
    }

    private fun prepareShareFile(name: String, bytes: ByteArray): File {
        return BackupShareCache.write(
            File(activity.cacheDir, "record-backup-share"), name, bytes,
        )
    }

    private fun shareExport(file: File) {
        val uri = FileProvider.getUriForFile(
            activity, "${activity.packageName}.diagnostics", file,
        )
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newUri(resolver, file.name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(
            Intent.createChooser(send, null).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
        )
    }

    fun dispose() {
        pickerResult?.error("picker_cancelled", "Activity was closed", null)
        pickerResult = null
        saveTarget?.let { target ->
            worker.execute {
                runCatching { deleteSavedDocument(target.uri) }
            }
            saveTarget = null
        }
        shareTarget?.let { target ->
            worker.execute { runCatching { target.file.parentFile?.deleteRecursively() } }
            shareTarget = null
        }
        worker.shutdown()
    }
}
