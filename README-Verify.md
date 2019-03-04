# Getting verify.app to work on Mac OS

Please note that at this time we only officially support the most recent release of Mac OS (10.14, Mojave). 

## Installing Swift support

You will need swift support, the quickest way to enable this on Mac OS is to install XCode from the app store. Simply load the Ap store and search for "XCode" and then install it.

## Installing LibreSSL via homebrew

You will need LibreSSL, the easiest way to install it is via brew. Simply go to https://brew.sh/ and follow the instructions to install brew. Once brew is installed you can install LibreSSL:

```
brew install libressl
```

You will then need to add LibreSSL to your PATH statement so the Verify.app can find and use it, add the LibreSSL directory to your PATH: 

```
  echo 'export PATH="/usr/local/opt/libressl/bin:$PATH"' >> ~/.bash_profile
```

The easiest way to ensure the PATH statement is reloaded is to simply log out and back in.

## Downloading and installing Verify.app

Verify.app is available as a zip file: https://github.com/opencpes/opencpes/releases/download/v0.0.1/Verify.zip.

No installation is needed, simply unzip the file (e.g. by double clicking on it). Please note that the Verify.app will create a local directory called opencpes-blockchain which contans a copy of the OpenCPEs Blockchain data. 
## Running Verify.app

The binary is unsigned, as such you will need to allow it in your Mac OS Security settings. Simply click on Verify.app to run it, you will receieve a warning. After the warning is presented click on "System Preferences" - "Security & Privacy" - "General" and then choose to allow the unsigned application Verify.app.

![Mac OS System Preferences](/images/system-preferences.png)

![Mac OS select application](/images/verify-allow.png)
