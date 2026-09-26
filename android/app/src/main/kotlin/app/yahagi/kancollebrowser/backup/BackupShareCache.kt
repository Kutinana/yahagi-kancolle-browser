package app.yahagi.kancollebrowser.backup

import java.io.File
import java.security.MessageDigest
import java.util.UUID

/** Each share gets a distinct URI, so an earlier recipient always reads its original bytes. */
internal object BackupShareCache {
    private const val MAX_BYTES = 100 * 1024 * 1024

    fun write(root: File, name: String, bytes: ByteArray): File {
        require(name.endsWith(".yhb") && name.length < 180 &&
            !name.contains('/') && !name.contains('\\')) { "Invalid backup name" }
        require(bytes.isNotEmpty() && bytes.size <= MAX_BYTES) { "Invalid backup size" }
        require(root.isDirectory || root.mkdirs()) { "Cannot prepare share cache" }
        val cutoff = System.currentTimeMillis() - 7L * 24 * 60 * 60 * 1000
        root.listFiles()?.filter { it.isDirectory && it.lastModified() < cutoff }
            ?.forEach { it.deleteRecursively() }

        val directory = File(root, UUID.randomUUID().toString())
        require(directory.mkdir()) { "Cannot prepare unique share file" }
        val target = File(directory, name)
        val pending = File(directory, "pending.tmp")
        val expectedHash = MessageDigest.getInstance("SHA-256").digest(bytes)
        try {
            pending.outputStream().use { it.write(bytes); it.flush() }
            require(verified(pending, bytes.size, expectedHash)) {
                "Shared backup verification failed"
            }
            if (!pending.renameTo(target)) {
                pending.copyTo(target)
                pending.delete()
            }
            require(verified(target, bytes.size, expectedHash)) {
                "Shared backup verification failed"
            }
            return target
        } catch (error: Throwable) {
            directory.deleteRecursively()
            throw error
        }
    }

    private fun verified(file: File, size: Int, expectedHash: ByteArray): Boolean {
        if (file.length() != size.toLong()) return false
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { stream ->
            val buffer = ByteArray(8192)
            while (true) {
                val count = stream.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().contentEquals(expectedHash)
    }
}
