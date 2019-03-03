# Getting verify.app to work on Mac OS

Please note that at this time we only officially support the most recent version of Mac OS (10.14.3), however Verify.app should work on recent versions as well.

## Installing Swift support

You will need swift support, the quickest way to enable this on Mac OS is to install XCode from the app store. Simply load the Ap store and search for "XCode" and then install it.

## Installing LibreSSL via homebrew

You will need LibreSSL, the easiest way to install it is via brew. Simply go to (https://brew.sh/)[https://brew.sh/] and follow the instructions to install brew. Once brew is installed you can install LibreSSL:

```
brew install libressl
```

You will then need to add LibreSSL to your PATH statement so the Verify.app can find and use it, add the LibreSSL directory to your PATH: 

```
  echo 'export PATH="/usr/local/opt/libressl/bin:$PATH"' >> ~/.bash_profile
```

The easiest way to ensure the PATH statement is reloaded is to simply log out and back in.

## Downloading and installing Verify.app

(https://opencpes.com/software-data-download/)[https://opencpes.com/software-data-download/]

No installation is needed, simply unzip the file. Please note that the Verify.app will create a local directory called opencpes-blockchain which contans a copy of the OpenCPEs Blockchain data. 

## Running Verify.app

The binary is unsigned, you will need to allow it:
