# HelloID-Conn-Prov-Target-Blue-Dolphin

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Blue-Dolphin/blob/main/Logo.jpg?raw=true">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-Blue-Dolphin](#helloid-conn-prov-target-blue-dolphin)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Supported features](#supported-features)
  - [Getting started](#getting-started)
    - [HelloID Icon URL](#helloid-icon-url)
    - [Requirements](#requirements)
    - [Connection settings](#connection-settings)
    - [Correlation configuration](#correlation-configuration)
    - [Field mapping](#field-mapping)
    - [Account Reference](#account-reference)
  - [Remarks](#remarks)
    - [SCIM](#scim)
    - [API Limitation](#api-limitation)
    - [Public API add-on activation](#public-api-add-on-activation)
    - [Role/Group terminology](#rolegroup-terminology)
    - [Correlation based on email address](#correlation-based-on-email-address)
    - [Enable/Disable actions](#enabledisable-actions)
    - [Duplicate mappings](#duplicate-mappings)
  - [Development resources](#development-resources)
    - [API endpoints](#api-endpoints)
    - [API documentation](#api-documentation)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Blue-Dolphin_ is a _target_ connector. _BlueDolphin_ provides a set of REST APIs that allow you to programmatically interact with its data.

## Supported features

The following features are available:

| Feature                                   | Supported | Actions                | Remarks                                                                            |
| ----------------------------------------- | --------- | ---------------------- | ---------------------------------------------------------------------------------- |
| **Account Lifecycle**                     | ✅         | Create, Update, Delete | No Enable and Disable. See remark [Enable/Disable actions](#enabledisable-actions) |
| **Permissions**                           | ✅         | Grant, Revoke          |                                                                                    |
| **Resources**                             | ❌         | -                      |                                                                                    |
| **Entitlement Import: Accounts**          | ✅         | -                      |                                                                                    |
| **Entitlement Import: Permissions**       | ✅         | -                      |                                                                                    |
| **Governance Reconciliation Resolutions** | ✅         | -                      |                                                                                    |

## Getting started

### HelloID Icon URL

URL of the icon used for the HelloID Provisioning target system.

```text
https://raw.githubusercontent.com/Tools4everBV/HelloID-Conn-Prov-Target-Blue-Dolphin/refs/heads/main/Logo.jpg
```

### Requirements

- **Public API add-on**: The BlueDolphin Public API add-on must be enabled on your tenant.
- **API access details**: A valid BaseUrl, TenantId, and AccessToken are required.

### Connection settings

The following settings are required to connect to the API.

| Setting     | Description                            | Mandatory |
| ----------- | -------------------------------------- | --------- |
| BaseUrl     | The URL to the API                     | Yes       |
| TenantId    | The tenant ID of the API               | Yes       |
| AccessToken | The access token to connect to the API | Yes       |

### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _BlueDolphin_ to a person in _HelloID_.

| Setting                   | Value                                                         |
| ------------------------- | ------------------------------------------------------------- |
| Enable correlation        | `True`                                                        |
| Person correlation field  | `PersonContext.Person.Accounts.MicrosoftActiveDirectory.mail` |
| Account correlation field | `emailAddress`                                                |

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

### Field mapping

The field mapping can be imported by using the _fieldMapping.json_ file.

### Account Reference

The account reference is populated with the `id` property from _BlueDolphin_.

## Remarks

### SCIM

- **SCIM**: The API is based on the SCIM (System for Cross-domain Identity Management) interface standard.

### API Limitation

- **One call every 250 milliseconds**: The API allows one call every 250 milliseconds per IP address. Exceeding this limit returns HTTP 429 (Too Many Requests).
- If you encounter this issue, try lowering the number of concurrent actions in HelloID.

### Public API add-on activation

- **Public API add-on**: This add-on must be enabled on your BlueDolphin tenant before API calls are possible.
- Contact your Account Manager to enable the add-on.
- If the add-on is not activated, calls to the BlueDolphin Public API will result in HTTP 403 (Forbidden).

### Role/Group terminology

- The application uses the term roles, while the API uses the term groups.
- A default group must be assigned to grant access to the application, such as `gebruikers`.

### Correlation based on email address

- **Email Address Correlation**: The connector relies on email addresses to correlate and match records between systems.
- Ensure email addresses are accurate and consistent across systems to prevent synchronization and matching issues.
- The API does not support filtering on GET calls, so the create action always retrieves all users.

### Enable/Disable actions

- **SSO**: This connector does not include enable or disable actions, as these are managed through SSO.
- **Import entitlements**: Since enable and disable actions are managed through SSO, the `enabled` property in the _importEntitlements_ action should always be set to `$false`.

### Duplicate mappings

- **Different account objects**: The User object returned by the API differs from the one used in the field mapping.
- As a result, the create, update, and import actions require duplicate mappings to ensure proper data handling.

## Development resources

### API endpoints

The following endpoints are used by the connector:

| Endpoint                        | HTTP Method              | Description                                            |
| ------------------------------- | ------------------------ | ------------------------------------------------------ |
| /scim/v2/{TenantId}/users       | GET, POST, PATCH, DELETE | Retrieve, create, update, and delete user information  |
| /scim/v2/{TenantId}/groups      | GET                      | Retrieve group information                             |
| /scim/v2/{TenantId}/groups/{id} | GET, PATCH               | Retrieve group memberships and update group membership |

### API documentation

> [!TIP]
> _For more information about the API, please refer to the BlueDolphin API [documentation](https://support.valueblue.nl/hc/en-us/categories/13253352426140-API-Documentation) pages_.

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/

