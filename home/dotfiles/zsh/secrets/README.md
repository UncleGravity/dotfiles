# Managing Encrypted Secrets for Zsh

This system uses Age encryption with 1Password SSH keys to securely manage secrets for your Zsh environment.

## File Structure

- `secrets.age`: Encrypted secrets file
- `secrets.sh`: Temporary decrypted secrets file (NOT tracked in version control)
- `_decrypt.sh`: Decrypts secrets.age into secrets.sh
- `_update.sh`: Updates secrets.sh with new secrets

## Usage

### Initial Setup

1. Run `_update.sh` to create or edit your secrets:
   ```
   ./zsh/secrets/_update.sh
   ```
   This will open your default editor to create or edit `secrets.sh`.

2. In the editor, add your secret environment variables:
   ```sh
   export SECRET_KEY="your_secret_value"
   export ANOTHER_SECRET="another_value"
   ```

3. Save and close the editor. The script will automatically encrypt `secrets.sh` into `secrets.age`.

4. Commit `secrets.age` to your repository. Do not commit `secrets.sh`.

### Decrypting Secrets

The `_decrypt.sh` script is automatically sourced in your `.zshrc`. It will:

1. Check if a decrypted `secrets.sh` exists.
2. If not, it will decrypt `secrets.age` using your SSH key.
3. Source the decrypted `secrets.sh` to set environment variables.

### Updating Secrets

1. Run `_update.sh` to decrypt, edit, and re-encrypt your secrets:
   ```
   ./zsh/secrets/_update.sh
   ```
2. This will open your default editor with the decrypted secrets.
3. Make your changes, save, and close the editor.
4. The script will automatically re-encrypt the changes and update `secrets.age`.
5. Commit the updated `secrets.age` file.

## Security Notes

- Never commit `secrets.sh` to version control.
- Ensure your 1Password account is secure.
- The `_update.sh` script temporarily creates a `secrets.sh` file but deletes it after encryption.