# Custom Node Kustomize Configuration

This directory contains a Kustomize-based configuration for deploying custom Canopy nodes with customizable genesis.json, keys, and SNAPSHOT_URL.

## Structure

```
custom_node/
├── base/                          # Base resources
│   ├── namespace.yaml            # Namespace definition
│   ├── nodes.yaml                # Regular node StatefulSet and Services
│   ├── seed-node.yaml            # Seed node StatefulSet and Services (10x peer capacity)
│   ├── configmaps.yaml           # ConfigMaps for regular node scripts and templates
│   ├── seed-configmaps.yaml      # ConfigMaps for seed node (with 10x maxInbound/maxOutbound)
│   ├── kustomization.yaml        # Base kustomization config
│   └── files/                    # Customizable files
│       ├── genesis.json          # Genesis file (customize this)
│       ├── validator-keys/       # Validator keys (customize these)
│       │   └── node1/
│       │       └── validator_key.json
│       └── keystores/           # Keystores (customize these)
│           └── node1/
│               └── keystore.json
└── overlays/
    └── default/                  # Default overlay
        ├── kustomization.yaml    # Overlay kustomization
        ├── snapshot-url-patch.yaml  # SNAPSHOT_URL patch
        ├── genesis-env-patch.yaml   # GENESIS_FILE patch for regular node
        └── seed-genesis-env-patch.yaml  # GENESIS_FILE patch for seed node
```

## Customization

### 1. Customize Genesis File

You have **three options** to provide the genesis file:

#### Option A: Via Environment Variable (Recommended for dynamic/secret values)

Edit the genesis environment variable patch:
```bash
vim custom_node/overlays/default/genesis-env-patch.yaml
```

Set the `GENESIS_FILE` value with your JSON content:
```yaml
- name: GENESIS_FILE
  value: '{"time": "2024-12-14", "accounts": [], ...}'
```

Or use a Secret reference:
```yaml
- name: GENESIS_FILE
  valueFrom:
    secretKeyRef:
      name: genesis-secret
      key: genesis.json
```

#### Option B: Via ConfigMap (from files/)

Edit the genesis file:
```bash
vim custom_node/base/files/genesis.json
```

#### Option C: Override in overlay

Override it in an overlay:
```bash
cp my-genesis.json custom_node/overlays/default/genesis.json
```

**Priority**: GENESIS_FILE env var > Localnet genesis ConfigMap > Custom-node ConfigMap > No genesis

### 2. Customize Validator Keys

Edit validator keys:
```bash
vim custom_node/base/files/validator-keys/node1/validator_key.json
```

Or add keys for additional nodes:
```bash
mkdir -p custom_node/base/files/validator-keys/node2
cp my-validator-key.json custom_node/base/files/validator-keys/node2/validator_key.json
```

Update `kustomization.yaml` to include additional nodes:
```yaml
configMapGenerator:
  - name: custom-node-validator-keys
    files:
      - validator-keys/node1/validator_key.json=validator-keys/node1/validator_key.json
      - validator-keys/node2/validator_key.json=validator-keys/node2/validator_key.json
```

### 3. Customize Keystores

Edit keystores:
```bash
vim custom_node/base/files/keystores/node1/keystore.json
```

### 4. Customize SNAPSHOT_URL

Edit the snapshot URL patch:
```bash
vim custom_node/overlays/default/snapshot-url-patch.yaml
```

Change the value:
```yaml
- name: SNAPSHOT_URL
  value: "http://your-custom-snapshot-url.com"
```

## Usage

### Build and Preview

Preview the generated manifests:
```bash
cd kubernetes-stack/custom_node/overlays/default
kubectl kustomize .
```

### Deploy

Deploy using kustomize:
```bash
cd kubernetes-stack/custom_node/overlays/default
kubectl apply -k .
```

Or build and apply:
```bash
cd kubernetes-stack/custom_node/overlays/default
kubectl kustomize . | kubectl apply -f -
```

### Create Custom Overlay

Create a new overlay for a specific environment:
```bash
mkdir -p custom_node/overlays/production
cp custom_node/overlays/default/* custom_node/overlays/production/
```

Then customize the files in the production overlay.

## Files to Customize

1. **genesis.json** - Blockchain genesis configuration
   - **Via ENV Variable**: `overlays/default/genesis-env-patch.yaml` (set `GENESIS_FILE`)
   - **Via Localnet ConfigMap**: Uses `canopy-localnet-genesis` ConfigMap if available (fallback)
   - **Via ConfigMap**: `base/files/genesis.json`
   - **Via Overlay**: Override in overlay directory
   - **Priority**: ENV Variable > Localnet ConfigMap > Custom-node ConfigMap > No genesis

2. **validator_key.json** - Validator private keys
   - Location: `base/files/validator-keys/node<N>/validator_key.json`
   - Add files for each node

3. **keystore.json** - Encrypted keystores
   - Location: `base/files/keystores/node<N>/keystore.json`
   - Add files for each node

4. **SNAPSHOT_URL** - Snapshot download URL
   - Location: `overlays/default/snapshot-url-patch.yaml`
   - Environment variable in init container

5. **Seed Node** - Additional seed node with 10x peer capacity
   - **StatefulSet**: `custom-node-seed` (deployed alongside regular node)
   - **Config**: `base/seed-configmaps.yaml` with `maxInbound: 210`, `maxOutbound: 70`
   - **GENESIS_FILE**: Can be set via `overlays/default/seed-genesis-env-patch.yaml`
   - **Purpose**: Supports more incoming connections for new nodes joining the network

## Security Notes

- **Never commit private keys or keystores to git**
- Add these files to `.gitignore`:
  ```
  custom_node/base/files/validator-keys/**/*.json
  custom_node/base/files/keystores/**/*.json
  custom_node/base/files/genesis.json
  ```
- Use Kubernetes Secrets for sensitive data in production
- Consider using Sealed Secrets or External Secrets Operator

## Examples

### Example 1: Custom Genesis via Environment Variable

```bash
# Edit genesis env patch
vim custom_node/overlays/default/genesis-env-patch.yaml

# Set GENESIS_FILE value with your JSON:
# - name: GENESIS_FILE
#   value: '{"time": "2024-12-14", "accounts": [], ...}'

# Build and deploy
cd custom_node/overlays/default
kubectl apply -k .
```

### Example 1b: Custom Genesis via ConfigMap

```bash
# Edit genesis file
vim custom_node/base/files/genesis.json

# Build and deploy
cd custom_node/overlays/default
kubectl apply -k .
```

### Example 1c: Custom Genesis via Secret

```bash
# Create a secret with genesis content
kubectl create secret generic genesis-secret \
  --from-file=genesis.json=my-genesis.json \
  -n custom-node

# Update genesis-env-patch.yaml to reference the secret:
# - name: GENESIS_FILE
#   valueFrom:
#     secretKeyRef:
#       name: genesis-secret
#       key: genesis.json

# Deploy
kubectl apply -k .
```

### Example 2: Custom Snapshot URL

```bash
# Edit snapshot URL
vim custom_node/overlays/default/snapshot-url-patch.yaml

# Change value to:
# value: "http://my-custom-snapshot.example.com"

# Deploy
kubectl apply -k .
```

### Example 3: Multiple Nodes with Different Keys

```bash
# Add keys for node2
mkdir -p custom_node/base/files/validator-keys/node2
cp my-node2-validator-key.json custom_node/base/files/validator-keys/node2/validator_key.json

# Update kustomization.yaml to include node2 keys
# Then update nodes.yaml to scale replicas to 2

# Deploy
kubectl apply -k .
```

### Example 4: Deploy Seed Node with Custom Genesis

The seed node is automatically deployed alongside the regular node. It has:
- **10x peer capacity**: `maxInbound: 210`, `maxOutbound: 70` (vs 21/7 for regular nodes)
- **Same genesis file**: Uses the same GENESIS_FILE or fallback logic as regular node
- **Separate service**: `custom-node-seed` service for connecting new nodes

```bash
# Set GENESIS_FILE for seed node (optional, will use same as regular node if not set)
vim custom_node/overlays/default/seed-genesis-env-patch.yaml

# Deploy both regular and seed nodes
kubectl apply -k .

# Check seed node status
kubectl get pods -n custom-node -l app=custom-node-seed
kubectl get svc -n custom-node | grep seed
```

**Seed Node Benefits:**
- Can handle up to 210 inbound connections (vs 21 for regular nodes)
- Can maintain up to 70 outbound connections (vs 7 for regular nodes)
- Ideal for bootstrap nodes that help new nodes join the network
- Uses same genesis file as regular node (supports GENESIS_FILE env var)

