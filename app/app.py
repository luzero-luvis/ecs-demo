from flask import Flask, render_template, jsonify
import os
import socket
import datetime

app = Flask(__name__)

@app.route("/")
def home():
    return render_template(
        "index.html",
        hostname=socket.gethostname(),
        version=os.environ.get("APP_VERSION", "1.0.0"),
        environment=os.environ.get("ENVIRONMENT", "development"),
        timestamp=datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC"),
    )

@app.route("/health")
def health():
    return jsonify(status="healthy", hostname=socket.gethostname())

@app.route("/info")
def info():
    return jsonify(
        app="ecr-demo",
        version=os.environ.get("APP_VERSION", "1.0.0"),
        environment=os.environ.get("ENVIRONMENT", "development"),
        hostname=socket.gethostname(),
        image_uri=os.environ.get("IMAGE_URI", "local"),
    )

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=False)
