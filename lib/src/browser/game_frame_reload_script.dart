const String gameFrameReloadScript = r'''
(() => {
  try {
    const gameFrame = document.getElementById('game_frame');
    let gameDocument = document;
    if (gameFrame) {
      gameDocument = gameFrame.contentDocument;
      if (!gameDocument) return 'blocked';
    }

    const game = gameDocument.getElementById('htmlWrap');
    if (!game) {
      return gameFrame ? 'html_wrap_not_found' : 'game_frame_not_found';
    }

    try {
      game.contentWindow.location.reload();
    } catch (_) {
      const source = game.getAttribute('src');
      if (!source) return 'blocked';
      game.setAttribute('src', source);
    }
    return 'reloaded';
  } catch (_) {
    return 'blocked';
  }
})()
''';
