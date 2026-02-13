import azure.functions as func
import json
import logging
import os

from azure.identity import DefaultAzureCredential
from azure.keyvault.keys import KeyClient
from azure.keyvault.secrets import SecretClient

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)


@app.route(route="list-keys", methods=["GET"])
def list_keys(req: func.HttpRequest) -> func.HttpResponse:
    """List all keys in the configured Azure Key Vault."""
    logging.info("Processing request to list Key Vault keys.")

    vault_uri = os.environ.get("KEY_VAULT_URI")
    if not vault_uri:
        return func.HttpResponse(
            json.dumps({"error": "KEY_VAULT_URI environment variable is not set."}),
            status_code=500,
            mimetype="application/json",
        )

    try:
        credential = DefaultAzureCredential()
        client = KeyClient(vault_url=vault_uri, credential=credential)

        keys = []
        for key_properties in client.list_properties_of_keys():
            keys.append(
                {
                    "name": key_properties.name,
                    "id": key_properties.id,
                    "enabled": key_properties.enabled,
                    "key_type": key_properties.key_type.value if key_properties.key_type else None,
                    "created_on": key_properties.created_on.isoformat() if key_properties.created_on else None,
                    "updated_on": key_properties.updated_on.isoformat() if key_properties.updated_on else None,
                    "expires_on": key_properties.expires_on.isoformat() if key_properties.expires_on else None,
                    "vault_url": key_properties.vault_url,
                }
            )

        logging.info("Found %d keys in Key Vault.", len(keys))

        return func.HttpResponse(
            json.dumps({"vault_uri": vault_uri, "key_count": len(keys), "keys": keys}, indent=2),
            status_code=200,
            mimetype="application/json",
        )

    except Exception as e:
        logging.exception("Failed to list keys from Key Vault.")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            mimetype="application/json",
        )


@app.route(route="list-secrets", methods=["GET"])
def list_secrets(req: func.HttpRequest) -> func.HttpResponse:
    """List all secrets in the configured Azure Key Vault."""
    logging.info("Processing request to list Key Vault secrets.")

    vault_uri = os.environ.get("KEY_VAULT_URI")
    if not vault_uri:
        return func.HttpResponse(
            json.dumps({"error": "KEY_VAULT_URI environment variable is not set."}),
            status_code=500,
            mimetype="application/json",
        )

    try:
        credential = DefaultAzureCredential()
        client = SecretClient(vault_url=vault_uri, credential=credential)

        secrets = []
        for secret_properties in client.list_properties_of_secrets():
            secrets.append(
                {
                    "name": secret_properties.name,
                    "id": secret_properties.id,
                    "enabled": secret_properties.enabled,
                    "content_type": secret_properties.content_type,
                    "created_on": secret_properties.created_on.isoformat() if secret_properties.created_on else None,
                    "updated_on": secret_properties.updated_on.isoformat() if secret_properties.updated_on else None,
                    "expires_on": secret_properties.expires_on.isoformat() if secret_properties.expires_on else None,
                    "vault_url": secret_properties.vault_url,
                }
            )

        logging.info("Found %d secrets in Key Vault.", len(secrets))

        return func.HttpResponse(
            json.dumps({"vault_uri": vault_uri, "secret_count": len(secrets), "secrets": secrets}, indent=2),
            status_code=200,
            mimetype="application/json",
        )

    except Exception as e:
        logging.exception("Failed to list secrets from Key Vault.")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            mimetype="application/json",
        )
