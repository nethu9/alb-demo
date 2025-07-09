from flask import Flask

app = Flask(__name__)
@app.route("/api")

def hello():
    return "Hello from Flask API", 200

if __name__ == "__main__":
    app.run("0.0.0.0", port=3000)
