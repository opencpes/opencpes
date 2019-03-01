# About OpenCPEs

OpenCPEs is a special Blockchain project from the CSA acting as a ledger for CPE (Continuing Professional Education) credits and other professional development accreditation and claims.

`OpenCPE` is a command line utility for interacting with and hosting blockchains based on a simple Winternitz one-time signature (WOTS) scheme.

The current iteration of the OpenCPEs chain is hosted on [Github](https://github.com/opencpes/opencpes-blockchain).

# Building

Enter the `OpenCPE` folder and run:

    swift build -c release

The build system will report where it places the resulting binary, which you are free to move elsewhere. On macOS, depending on your system, you may need to install the homebrew version of `libressl`. MacPorts has been known to interfere with successful builds. A simple way to temporarily disable MacPorts is to rename the `/opt/local` directory (e.g. to `/opt/lcl`) and then name it back to `/opt/local` after building.

# Simple Witnessing

You can use the OpenCPEs chain to witness attachments to e-mails sent to [centsi@opencpes.com](mailto:centsi@opencpes.com). Keep your original file. In the case of images sent via phone it may be better to CC yourself as phones often manipulate images before transmission.

To verify `foo.dat` after sending, `git clone` the latest [OpenCPEs blockchain](https://github.com/opencpes/opencpes-blockchain). Determine `foo.dat`'s SHA512 sum:

    HASH=`sha512sum --tag foo.dat | sed -e 's/.* //'`

`git pull` in the blockchain repo to syncronise it and then determine the top block:

    TOP=`cat /path/to/opencpes-blockchain/chain/top.txt`

Verification is performed by finding the value in a "key series" starting with a "fundamental key". The current fundamental key is `319da1be59a03c7250f5fc4d8b4e78d3280d2d8605be0ac2f68b3d936301382dd09410b59a25dea58f3fd8c3de98cd21c14f32c79cfb29b9df211f50ecff27ed`. Use it to verify your search:

    /path/to/OpenCPE find -v "$HASH" -f "319da1be59a03c7250f5fc4d8b4e78d3280d2d8605be0ac2f68b3d936301382dd09410b59a25dea58f3fd8c3de98cd21c14f32c79cfb29b9df211f50ecff27ed" -t "$TOP"

This will search the chain for the `$HASH` value.

# Next Steps

Check out the `examples/demo` directory to see how the e-mail based back-end was implemented. 
