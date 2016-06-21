# lamp-server-cookbook

Basic Linux-Apache-MySQL-PHP server setup.

Sets up our server to run a standard LAMP stack setup.

## Supported Platforms

* RHEL/Fedora/CentOS
* Debian/Ubuntu

## Attributes

None at this time.

## Usage

### lamp-server::default

Include `lamp-server` in your node's `run_list`:

```json
{
  "run_list": [
    "recipe[lamp-server::default]"
  ]
}
```

## Notes

We run MariaDB instead of MySQL.  Unfortunately this causes problem
with the default `php` cookbook, which is hardcoded to use MySQL.
We get around this by using [our own fork of the `php` cookbook](https://github.com/opengovfoundation/cookbook-php)

# TODO

Split out the Madison and Wordpress specific code into their own cookbooks.

## License

[CC0 Licensed](https://creativecommons.org/publicdomain/zero/1.0/)
