# Paperless preprocess pipeline

Preprocessing pipeline for cleaning, enhancing, and compressing scanned
documents before they're imported into paperless-ng. Uses opencv and [unpaper].

## Features

- Smoothes and de-noises raw scans using the edge-preserving [Bilateral
  filtering algorithm].
- Automatically crops and rotates the document within the scanned image.
- Automatically detects and removes blank pages. Very useful for scanners that
  scan both sides of a document.
- Thresholds the image to black and white using [Otsu's algorithm] to improve
  OCR accuracy and reduce storage requirements.
- Does all of the above _before_ sending the image to [unpaper] for further
  noise and artifact reduction!
- Supports batch processing of documents for scanners that have an automatic
  document feed. Merges cleaned images into a single compressed file.
- Able to process raw scanned image in many formats, including pnm, ppm, pbm,
  and tiff.

## Motivation

The [paperless-ng] project is a great tool for digitizing and organizing paper
documents. It has excellent document post-processing features including
machine-learning powered tagging, document metadata autofill, search indexing,
and automatic OCR. It presents all your documents in an intuitive, modern UI.

While paperless-ng's post-processing tools are top-notch, in the case of
scanned documents it relies entirely on the user to provide quality,
pre-processed images for it to consume. Every feature listed above fills a gap
in paperless-ng's functionality.

## Setup

These instructions have been tested on Ubuntu 22.04.

### Scanner setup

Setup your scanner using the SANE (scanner access not easy) software:

```bash
# Make sure universe repository is enabled
sudo add-apt-repository universe

# Install SANE (scanner access now easy) tools
sudo apt install libsane sane-utils
```

Find which backend supports your scanner by going to the [SANE backends] page
and searching for your model of scanner. Be sure to click on the link to the
backend-specific manpage to see if there's any further setup necessary.

If you're using a physically connected scanner, add yourself to the `scanner`
group so you can access the device:

`sudo usermod -aG scanner $USER`

Log out and back in for the group change to take effect. Better yet, reboot.

Connect and turn on your scanner if you haven't already, and check that it's
detected by running `scanimage -L`. You should see output similar to
``device `epjitsu:libusb:002:014' is a FUJITSU ScanSnap S1300i scanner``.
If you don't, make sure scanner is awake and ready to scan,
and try some of the troubleshooting methods described in the [sane
Troubleshooting guide]. You can also set environment variables to enable
various levels of debug output, e.g. `SANE_DEBUG_DLL=5 SANE_DEBUG_SANEI_USB=4
scanimage -L`. See the manpages for `sane-dll`, `sane-usb`, and your specific
sane backend for more info on debug levels.

Once successful, find out what scan options are available for your scanner
device by running `scanimage --help`. Run a test scan with your desired options
and check that the output image is as expected.


### Paperless-ng setup

Run through [paperless-ng's setup guide] to install and start paperless-ng. I
recommend using the docker-compose method. You can configure and run
paperless-ng directly from a clone of this repo if you want - the config files
and runtime directories will be ignored by git.

For configuration, the only recommended setting to use this pipeline is
`PAPERLESS_OCR_CLEAN=none`. This disables paperless-ng's use of [unpaper],
which is desirable since it's already used by the preprocessing pipeline.

As a convenience, you can bootstrap paperless-ng's config using this script:

```bash
# set paperless secret key to a random string
export PAPERLESS_SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
# set uid and gid to match current user
export USERMAP_UID=$(id -u)
export USERMAP_GID=$(id -g)
# set timezone to match host timezone
export PAPERLESS_TIME_ZONE=$(timedatectl show --property=Timezone --value)
envsubst '$PAPERLESS_SECRET_KEY:$USERMAP_UID:$USERMAP_GID:$PAPERLESS_TIME_ZONE' < ./docker-compose.env.template > docker-compose.env
```

You may want to take this opportunity to review [paperless-ng's configuration]
for other environment variables you may want to set.

### Push-button paperless integration with scanbd

Scanbd is the scanner button daemon. It polls the scanner for button presses
and triggers a user-defined script. We'll use this to integrate our scanner
with paperless-ng.

```bash
sudo apt install scanbd unpaper python3 python3-venv libtiff-tools
```

Edit `/etc/scanbd/scanbd.conf`. Most settings will be left the same, but
there are a few that are worth changing:

- Comment out the `saned_env { ... }` line. It tells saned to use a different
  folder for its configuration which is unnecessary and confusing.
- The script pointed to under the `action scan {` section should be changed
  from `test.script` to this repo's `scanbd_trigger.sh`.
- Comment out or remove all `include` directives that load specific backends.
  These can be found at the bottom of the file.

Setup the scanbd target script:

```
python3 -m venv _venv
. _venv/bin/activate
pip install -r requirements.txt
sudo mkdir -p /etc/scanbd/scripts
sudo ln -s $(pwd)/scanbd_trigger.sh /etc/scanbd/scripts/scanbd_trigger.sh
sudo systemctl restart scanbd
```

## TODO

- Better secrets management for `PAPERLESS_SECRETS_KEY` (as described in
  [jonaswinkler/paperless-ng#1236]). For now I'm just saving the key to a
  git-ignored file.
- Detect and clean up dark edges and corners in scanned document. Ideally this
  would be done by applying adaptive thresholding to those regions to preserve
  content.

[Bilateral filtering algorithm]: https://homepages.inf.ed.ac.uk/rbf/CVonline/LOCAL_COPIES/MANDUCHI1/Bilateral_Filtering.html
[jonaswinkler/paperless-ng#1236]: https://github.com/jonaswinkler/paperless-ng/issues/1236
[Otsu's algorithm]: https://docs.opencv.org/4.5.5/d7/d4d/tutorial_py_thresholding.html
[paperless-ng]: https://paperless-ng.readthedocs.io/en/latest/index.html
[paperless-ng's configuration]: https://paperless-ng.readthedocs.io/en/latest/configuration.html
[paperless-ng's setup guide]: https://paperless-ng.readthedocs.io/en/latest/setup.html
[SANE backends]: http://www.sane-project.org/sane-backends.html
[sane Troubleshooting guide]: https://help.ubuntu.com/community/sane_Troubleshooting
[unpaper]: https://github.com/unpaper/unpaper
