abstract final class OoiConnectorAssist {
  static bool shouldRun(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.toLowerCase() == 'ooi.moe' &&
        !uri.hasPort &&
        uri.userInfo.isEmpty;
  }

  static const script = r'''(() => {
    const target = document.querySelector('input[name="mode"][value="4"]');
    if (!target) return 'missing';
    target.checked = true;
    target.dispatchEvent(new Event('change', { bubbles: true }));
    for (const value of ['1', '3']) {
      const option = document.querySelector(`input[name="mode"][value="${value}"]`);
      const row = option && (option.closest('label') || option.parentElement);
      if (row) row.style.display = 'none';
      if (option) option.disabled = true;
    }
    return 'ready';
  })();''';
}
