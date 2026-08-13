# CRS804

MikroTik CRS804-4DDQ providing the 200 Gbit/s Spark fabric, managed at `crs804.localdomain` with RouterOS.

## Health

```bash
ssh admin@crs804.localdomain '/system health print'
ssh admin@crs804.localdomain '/system health settings print'
```

## Apply configuration

```bash
scp infra/mikrotik-crs804/configuration.rsc admin@crs804.localdomain:configuration.rsc
ssh admin@crs804.localdomain '/import file-name=configuration.rsc verbose=yes'
```
