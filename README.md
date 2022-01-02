# One-touch solution for paperless-ng

This repo integrates your scanner with paperless-ng to provide an all-in-one
solution for going paperless. Push button, get clean, searchable PDF.

## Motivation

The [paperless-ng] project is a great tool for digitizing and organizing paper
documents. It has great document post-processing features including
machine-learning powered tagging, document metadata autofill, search indexing,
and automatic OCR. It presents all your documents in an intuitive, modern UI.

While paperless-ng's post-processing tools are top-notch, in the case of
scanned documents it relies entirely on the user to provide quality,
pre-processed images for it to consume. This repo aims to fill that gap.

## Setup

These instructions have been tested on Ubuntu 22.04.

### Scanner setup

Setup your scanner using the SANE (scanner access not easy) software:

```bash
# Make sure universe repository is enabled
sudo add-apt-repository universe

# Install SANE (scanner access now easy) tools
# TODO scanbd?
sudo apt install libsane sane-utils
```

Find which backend supports your scanner by going to the [SANE backends] page
and searching for your model of scanner. Be sure to click on the link to the
backend-specific manpage to see if there's any further setup necessary.

If you're using a physically connected scanner, add yourself to the `saned`
group so you can access the device:

`sudo usermod -aG saned $USER`

Log out and back in for the group change to take effect. Better yet, reboot.

Connect and turn on your scanner if you haven't already, and check that it's is
detected by running `scanimage -L`. You should see output similar to
``device `epjitsu:libusb:002:014' is a FUJITSU ScanSnap S1300i scanner``.
If you don't, make sure scanner is awake and ready to scan,
and try some of the troubleshooting methods described in the [sane
Troubleshooting guide].

If successful, find out what scan options are available for your scanner device
by running `scanimage --help`. Run a test scan with your desired options and
check that the output image is as expected.

### Paperless-ng setup

We'll be using the docker-compose method of running paperless-ng. Start by
installing docker and docker-compose:

```bash
# Add Docker repository to apt

# apt-key is deprecated as of 22.04. Add key using gpg directly
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/docker-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update

# Install docker and docker-compose to run paperless-ng
sudo apt install docker-ce docker-compose
```

Next, make sure you're logged in as the user you want paperless-ng to save
files as, and clone this repo into the directory that you want to run
paperless-ng out of:

```bash
git clone https://github.com/teekennedy/one-touch-paperless-ng.git paperless-ng
cd paperless-ng
```

Configure paperless-ng by substituting variables in [/webserver.env.template]
with values from the current environment. The resulting webserver.env will
contain sensitive information and is ignored by git.

```bash
export PAPERLESS_SECRETS_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
export USERMAP_UID=$(id -u)
export USERMAP_GID=$(id -g)
export PAPERLESS_TIME_ZONE=$(timedatectl show --property=Timezone --value)
envsubst '$PAPERLESS_SECRETS_KEY:$USERMAP_UID:$USERMAP_GID:$PAPERLESS_TIME_ZONE' < ./webserver.env.template > webserver.env
```

You may want to take this opportunity to review [paperless-ng's configuration]
for other environment variables you may want to set.

Finally, start the services and create the initial superuser for the web UI:

```bash
docker-compose pull
docker-compose up -d
docker-compose run --rm webserver createsuperuser
```

You'll be prompted for a username, email address, and password. With that all
set you should be able to go to http://localhost:8000 and login!

The docker services are set to restart until stopped, so paperless-ng will
continue to run across reboots.

## TODO

- Better secrets management for `PAPERLESS_SECRETS_KEY` (as described in
  [jonaswinkler/paperless-ng#1236]). For now I'm just saving the key to a
  git-ignored file.

[paperless-ng]: https://paperless-ng.readthedocs.io/en/latest/index.html
[paperless-ng's configuration]: https://paperless-ng.readthedocs.io/en/latest/configuration.html
[SANE backends]: http://www.sane-project.org/sane-backends.html
[sane Troubleshooting guide]: https://help.ubuntu.com/community/sane_Troubleshooting
