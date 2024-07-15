# Managing Encrypted Secrets for Zsh

This system uses Age encryption with GitHub SSH keys to securely manage secrets for your Zsh environment.

## File Structure

- `secrets.age`: Encrypted secrets file
- `secrets.sh`: Temporary decrypted secrets file (NOT tracked in version control)
- `_decrypt.sh`: Script to decrypt secrets
- `_update.sh`: Script to update encrypted secrets
- `_rotate.sh`: Script to re-encrypt secrets with updated GitHub keys

## Usage

### Initial Setup

1. Create a `secrets.sh` file with your secret environment variables:
   ```sh
   export SECRET_KEY="your_secret_value"
   export ANOTHER_SECRET="another_value"
   ```

2. Run `_update.sh` to encrypt `secrets.sh` into `secrets.age`:
   ```
   ./zsh/secrets/_update.sh
   ```

3. Commit `secrets.age` to your repository. Do not commit `secrets.sh`.

### Decrypting Secrets

The `_decrypt.sh` script is automatically sourced in your `.zshrc`. It will:

1. Check if a decrypted `secrets.sh` exists.
2. If not, it will decrypt `secrets.age` using your SSH key.
3. Source the decrypted `secrets.sh` to set environment variables.

### Updating Secrets

1. Modify `secrets.sh` with your updated secrets.
2. Run `_update.sh` to re-encrypt the changes:
   ```
   ./zsh/secrets/_update.sh
   ```
3. Commit the updated `secrets.age` file.

### Rotating Keys

When updating your GitHub SSH keys or setting up a new machine:

1. Run `_rotate.sh` to re-encrypt `secrets.age` with your current GitHub SSH keys:
   ```
   ./zsh/secrets/_rotate.sh
   ```
2. Commit the updated `secrets.age` file.

## Security Notes

- Never commit `secrets.sh` to version control.
- Ensure your GitHub account and SSH keys are secure.
- Regularly update your secrets and rotate your GitHub SSH keys.