#! /bin/sh

SANDBOX=./node_modules/electron/dist/chrome-sandbox

bun install
sudo chown root $SANDBOX
sudo chmod 4755 $SANDBOX
