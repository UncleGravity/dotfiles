#!/usr/bin/env node

process.stdout.write("ready\n")
process.stdin.resume()
process.stdin.once("end", () => process.exit(0))
process.stdin.once("close", () => process.exit(0))
