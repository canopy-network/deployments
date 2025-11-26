# Custom Node Overlay - Default

This overlay demonstrates how to customize the custom-node deployment.

## Environment Variables

### GENESIS_FILE

Set the genesis file content via environment variable in `genesis-env-patch.yaml`:

```yaml
- name: GENESIS_FILE
  value: '{"time": "2024-12-14", "accounts": [], ...}'
```

**Benefits:**
- Can be set dynamically at deployment time
- Can reference Kubernetes Secrets for sensitive data
- Overrides ConfigMap-based genesis file

**Example with Secret:**
```yaml
- name: GENESIS_FILE
  valueFrom:
    secretKeyRef:
      name: genesis-secret
      key: genesis.json
```

### SNAPSHOT_URL

Set the snapshot download URL in `snapshot-url-patch.yaml`:

```yaml
- name: SNAPSHOT_URL
  value: "http://your-custom-snapshot-url.com"
```

## Usage

### Deploy with default values:
```bash
kubectl apply -k .
```

### Deploy with custom genesis from env var:
1. Edit `genesis-env-patch.yaml` and set `GENESIS_FILE` value
2. Deploy: `kubectl apply -k .`

### Deploy with custom genesis from Secret:
1. Create secret:
   ```bash
   kubectl create secret generic genesis-secret \
     --from-file=genesis.json=my-genesis.json \
     -n custom-node
   ```
2. Update `genesis-env-patch.yaml` to use `valueFrom.secretKeyRef`
3. Deploy: `kubectl apply -k .`

## Priority Order

The genesis file is loaded in this order:
1. **GENESIS_FILE** environment variable (highest priority)
2. **Localnet genesis ConfigMap** (`canopy-localnet-genesis`) - if available
3. **Custom-node genesis ConfigMap** (`custom-node-genesis`) from `base/files/genesis.json`
4. **No genesis file** - node will sync from network

This allows you to:
- Override with env var for dynamic/secret values
- Fall back to localnet genesis if you have it deployed
- Use custom genesis from files/ if neither above is set
- Start without genesis if none are available

