# Bosh release for a SSL Proxy

One of the fastest ways to get a SSL proxy in front of your CloudFoundry router running on any infrastructure is too deploy this bosh release.

## Usage

To use this bosh release, first upload it to your bosh:

```
bosh target BOSH_URL
bosh login
git clone https://github.com/cloudfoundry-community/sslproxy-boshrelease.git
cd sslproxy-boshrelease
bosh upload release releases/sslproxy-5.yml
```

Now update the `examples/openstack*.yml` woth your settings (look up for #CHANGE).

Finally, target and deploy. For deployment to a bosh running on openstack:

```
bosh deployment examples/dns.yml
bosh verify deployment
bosh deploy
```

The `bosh verify deployment` is a local bosh CLI plugin to pre-verify your deployment file for correctness and matching SSL certificate/key.

### Self-signed certificates by default

By default you do not need to provide a signed SSL certificate. This is very useful for dev/test deployments.

It will mean that Chrome users, for example, will see the red-screen-of-fear. So, its not ideal for production and your lovely end users.

### BYO certificates

For production you will want to configure your SSL proxy with a signed certificate. You will need two files (or their contents):

* certificate key without a passphrase
* certificate (with chained intermediate certificates)

The *certificate key* file will likely have a `.key` suffix and its contents will look like:

```
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA5y0/Mzx0t5cMTCvXHocTjF7XCYLxP0EKwA2eI41q+tMblQ7m
...
N2bfPlzHpvFMOBsoQBK1XzrbobeZ7h96yLIw5tFwcO4P6ASCJeQt
-----END RSA PRIVATE KEY-----
```

The *chained certificate* file will contain multiple certificates. The top one is the certificate you purchased. Downwards in the file are the intermediate certificates, finishing the the root certificate. You may need to construct the chained certificate yourself.

For example, the chained certificate contents will look like:

```
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
```

The content of these two files will now be added to the properties section of your deployment file:

``` yaml
properties:
  router:
    servers:
      - 0.router.default.cf.microbosh
      - 1.router.default.cf.microbosh

  sslproxy:
    https:
      ssl_key: |
        -----BEGIN RSA PRIVATE KEY-----
        MIIEowIBAAKCAQEA5y0/Mzx0t5cMTCvXHocTjF7XCYLxP0EKwA2eI41q+tMblQ7m
        ...
        N2bfPlzHpvFMOBsoQBK1XzrbobeZ7h96yLIw5tFwcO4P6ASCJeQt
      ssl_cert: |
        -----BEGIN CERTIFICATE-----
        MIIFAzCCA+ugAwIBAgIDAeiTMA0GCSqGSIb3DQEBBQUAMEAxCzAJBgNVBAYTAlVT
        ...
        -----END CERTIFICATE-----
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
```

Note, the `|` after `ssl_key:` and `ssl_cert:` means the following lines are a multi-line string and the end-of-line `\n` are to be retained.

### After Steps

Once your SSL proxy is deployed all you need to do is point your Cloud Foundry floating IP at it. i.e. if your DNS name for the Cloud Foundry director is *.cf.mycloud.com, then you need to point that to your SSL proxy IP.

## Development

### Create new final release

To create a new final release you need to get read/write API credentials to the [@cloudfoundry-community](https://github.com/cloudfoundry-community) s3 account.

Please email [Dr Nic Williams](mailto:&#x64;&#x72;&#x6E;&#x69;&#x63;&#x77;&#x69;&#x6C;&#x6C;&#x69;&#x61;&#x6D;&#x73;&#x40;&#x67;&#x6D;&#x61;&#x69;&#x6C;&#x2E;&#x63;&#x6F;&#x6D;) and he will create unique API credentials for you.

Create a `config/private.yml` file with the following contents:

``` yaml
---
blobstore:
  s3:
    access_key_id:     ACCESS
    secret_access_key: PRIVATE
```

You can now create final releases for everyone to enjoy!

```
bosh create release
# test this dev release
git commit -m "updated sslproxy"
bosh create release --final
git commit -m "creating vXYZ release"
git tag vXYZ
git push origin master --tags
```
