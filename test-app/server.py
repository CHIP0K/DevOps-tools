from http.server import HTTPServer, BaseHTTPRequestHandler
import socket
import sys

SERVER_BIND_IP = '0.0.0.0'
SERVER_PORT = 8000
arg1 = int(sys.argv[1])
arg2 = int(sys.argv[2])
arg3 = str(sys.argv[3])


class SimpleHTTPRequestHeader(BaseHTTPRequestHandler):
	def do_GET(self):
		self.send_response(200)
		self.send_header('Content-type', 'text/html')
		self.end_headers()
		self.wfile.write(b'<h1><font color=green> Hello from Kubernates!</font color></h1>'+ b'<br>')
		self.wfile.write(b'<b>Hostname: </b>' + socket.gethostname().encode() + b'<br>')
		self.wfile.write(b'<b>Server ip address is </b>' + socket.gethostbyname("localhost").encode() + b'<br>')
		self.wfile.write(b'<b>Arg 1: </b>' + str(arg1).encode() + b'<br>')
		self.wfile.write(b'<b>Arg 2: </b>' + str(arg2).encode() + b'<br>')
		self.wfile.write(b'<b>Arg 3: </b>' + str(arg3).encode() + b'<br>')


httpd = HTTPServer((SERVER_BIND_IP, SERVER_PORT), SimpleHTTPRequestHeader)
print(f'Listening on: {SERVER_BIND_IP}:{SERVER_PORT}')
httpd.serve_forever()
