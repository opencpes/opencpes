const fs = require('fs');
const { spawn, execSync } = require('child_process');

execSync("rm /tmp/req ; mkfifo /tmp/req");
execSync("rm /tmp/rsp ; mkfifo /tmp/rsp");

const sub = spawn(
  "/opt/lib/ld-linux-x86-64.so.2",
  ["--library-path","/opt/lib","./Observations"],
  {
    detached: true,
    stdio: 'inherit'
  }
);
sub.unref()

exports.handler = async (event) => {
  fs.appendFileSync("/tmp/req",JSON.stringify(event));
  return JSON.parse(fs.readFileSync("/tmp/rsp"));
};
