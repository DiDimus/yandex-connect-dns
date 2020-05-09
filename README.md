# yandex-connect-dns
Shell script for updating current IP using yandex.connect

# Requirements
bash

curl

jq

## How to use?
1. Clone or copy yandex-connect-dns.sh
```bash
git clone https://github.com/DiDimus/yandex-connect-dns
```

2. Make yandex-connect-dns.sh to execute.
```bash
chmod +x yandex-connect-dns.sh
```
3. Create settings.ini with the following contents:

```text
example.com:123456789ABCDEF0000000000000000000000000000000000000
```
where example.com - your domain, 123456789ABC... - API token. Get it here - https://pddimp.yandex.ru/api2/admin/get_token

4. Launch script or create a cron job like this
```bash
0,15,30,45 * * * * bash yandex-connect-dns.sh
```

Now, you are done.
