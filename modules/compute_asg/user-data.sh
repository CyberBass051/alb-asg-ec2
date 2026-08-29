#!/bin/bash
dnf install -y nginx

cat > /usr/share/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>:: CYBERBASS_NODE ::</title>
<style>
  body {
    background: #0a0a0f;
    color: #00ffcc;
    font-family: 'Courier New', monospace;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100vh;
    margin: 0;
    text-shadow: 0 0 8px #00ffcc;
  }
  h1 {
    font-size: 3rem;
    letter-spacing: 4px;
    animation: flicker 3s infinite;
  }
  .bass-line {
    width: 60%;
    height: 4px;
    background: linear-gradient(90deg, #ff00d4, #00ffcc, #ff00d4);
    margin: 20px 0;
    animation: pulse 1.4s infinite;
  }
  p { color: #ff00d4; letter-spacing: 2px; }
  .tag { position: absolute; bottom: 20px; font-size: 0.8rem; color: #444; }
  @keyframes flicker {
    0%, 19%, 21%, 23%, 25%, 54%, 56%, 100% { opacity: 1; }
    20%, 24%, 55% { opacity: 0.4; }
  }
  @keyframes pulse {
    0%, 100% { transform: scaleX(1); opacity: 1; }
    50% { transform: scaleX(0.6); opacity: 0.6; }
  }
</style>
</head>
<body>
  <h1>CYBERBASS://ONLINE</h1>
  <div class="bass-line"></div>
  <p>WEB TIER // NODE ACTIVE // AWAITING SIGNAL</p>
  <div class="tag">deployed via terraform · asg-managed · low-latency groove</div>
</body>
</html>
EOF

cat > /usr/share/nginx/html/health << 'EOF'
OK
EOF

systemctl enable nginx
systemctl start nginx