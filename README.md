# vault-secrets-fetcher

Wrapper script that fetches secrets from Vault and exports them as environment variables. Check out [my blog post](https://trollab.ca/posts/ci_secrets_from_vault/) on this for more details.

Vault URL, KV path and credentials are in `envvars` file but can be easily read from environment variables if you keep `envvars` file empty.


## How to test it out

First do read the [blog post](https://trollab.ca/posts/ci_secrets_from_vault/), then setup your Vault, then clone this repo and run:

```SH
./wrapper.sh tester.sh
```

In real use case `tester.sh` would be your deployment script in the CI/CD pipeline that need secrets from Vault.
