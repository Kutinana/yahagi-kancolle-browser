const String gameLocalHomeHtml = '''
<!doctype html>
<html lang="zh-CN">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
html,body{height:100%;margin:0;background:#102431;color:#c7d5dc;font-family:sans-serif}
body{display:flex;align-items:center;justify-content:center}
main{text-align:center;padding:28px}h2{color:#d4a85f}p{color:#8299a5;line-height:1.6}
button{border:1px solid #5d786f;border-radius:8px;background:#183631;color:#80c8bd;padding:10px 14px}
</style>
<main>
  <h2>游戏 WebView 测试首页</h2>
  <p>这里不会连接真实账号，<br>使用上方“DMM 登录测试”主动进入真实网页。</p>
  <button onclick="YahagiBridge.postMessage(JSON.stringify({
    kind:'kcsapi-response',
    path:'/kcsapi/api_port/port',
    body:'svdata={&quot;api_result&quot;:1}',
    source:'manual',
    capturedAt:new Date().toISOString()
  }))">发送模拟舰队数据</button>
</main>
</html>
''';
