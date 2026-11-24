# The core application (a test-only dependency) is running in this VM as the
# daemon. Point the client at its socket.
System.put_env("STRATTA_SOCKET", Stratta.Socket.path())
ExUnit.start()
