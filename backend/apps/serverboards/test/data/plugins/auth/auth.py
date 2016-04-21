#!/usr/bin/python
from __future__ import print_function
import serverboards, sys

@serverboards.rpc_method
def auth(type="fake", token=None):
    if token=="XXX":
        return 'dmoreno@serverboards.io'
    return False

@serverboards.rpc_method
def ping(*args):
    return 'pong'

@serverboards.rpc_method
def abort(*args):
    sys.stderr.write("Aborting\n")
    os.exit(1)

@serverboards.rpc_method
def bad_protocol(*args):
    sys.stdout.write("Invalid message\n")
    return True

#print(serverboards.__dir(), file=sys.stderr)
serverboards.loop(debug=sys.stderr)
