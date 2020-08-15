require 'socket'
require 'openssl'

HOST = 'localhost'
PORT = 1965
PUBLIC_DIR = 'public'
CERT = 'certs/localhost.crt'
PRIVATE_KEY = 'certs/localhost.key'

RESPONSE_CODE = {
  ok: 20,
  not_found: 51,
}

def init_server
  rsa_cert = OpenSSL::X509::Certificate.new(File.open(CERT))
  rsa_pkey = OpenSSL::PKey.read(File.open(PRIVATE_KEY))
  tcp_server = TCPServer.new(PORT)
  ctx = OpenSSL::SSL::SSLContext.new
  ctx.add_certificate(rsa_cert, rsa_pkey)
  ssl_server = OpenSSL::SSL::SSLServer.new(tcp_server, ctx)
end

def serve(server)
  while session = server.accept
    request = session.gets
    puts request
    path = resolve_path(request)
    if !path
      puts "Not found: #{request}"
      session.print "#{RESPONSE_CODE[:not_found]} text/gemini; lang=en\r\n"
      session.close
      next
    end

    session.print "20 text/gemini; lang=en\r\n"
    load_file(path) do |content|
      puts content
      session.print content
    end
    session.print "Served at: #{Time.now}"
    session.close
  end
end

def resolve_path(string)
  url_path = parse_path(string)
  file_path = "#{PUBLIC_DIR}/#{url_path}.gmi"
  return file_path if File.exist?(file_path)
  dir_path = "#{PUBLIC_DIR}/#{url_path}/index.gmi"
  return dir_path if File.exist?(dir_path)
  return false
end

def parse_path(string)
  string.strip
    .delete_prefix("gemini://#{HOST}:#{PORT}")
    .delete_prefix('/')
    .delete_suffix('.gmi')
end

def load_file(path)
  puts "Serving #{path}"
  IO.foreach(path) do |content|
    yield content
  end
end

def main
  server = init_server
  serve(server)
end

main
