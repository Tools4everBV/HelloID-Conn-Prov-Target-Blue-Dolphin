# HelloID-Conn-Prov-Target-Blue-Dolphin

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-Blue-Dolphin](#helloid-conn-prov-target-blue-dolphin)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Supported  features](#supported--features)
  - [Getting started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Connection settings](#connection-settings)
    - [Correlation configuration](#correlation-configuration)
    - [Field mapping](#field-mapping)
    - [Account Reference](#account-reference)
  - [Remarks](#remarks)
    - [SCIM](#scim)
    - [API Limitation](#api-limitation)
    - [Correlation Based on Email Address](#correlation-based-on-email-address)
    - [Enable/Disable Actions](#enabledisable-actions)
    - [Default role](#default-role)
    - [Duplicate mappings](#duplicate-mappings)
  - [Development resources](#development-resources)
    - [API endpoints](#api-endpoints)
    - [API documentation](#api-documentation)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Blue-Dolphin_ is a _target_ connector. _Blue-Dolphin_ provides a set of REST API's that allow you to programmatically interact with its data.

## Supported  features

The following features are available:

| Feature                                   | Supported | Actions                | Remarks                                                                                                   |
| ----------------------------------------- | --------- | ---------------------- | --------------------------------------------------------------------------------------------------------- |
| **Account Lifecycle**                     | ✅         | Create, Update, Delete | No Enable and Disable. See remark [Enable/Disable Actions](#enabledisable-actions)                                                                                     |
| **Permissions**                           | ❌         | -                      | Users are assigned the Alleen Lezen (Read-Only) role by default. See remark [Default role](#default-role) |
| **Resources**                             | ❌         | -                      |                                                                                                           |
| **Entitlement Import: Accounts**          | ✅         | -                      |                                                                                                           |
| **Entitlement Import: Permissions**       | ❌         | -                      |                                                                                                           |
| **Governance Reconciliation Resolutions** | ❌         | -                      |                                                                                                           |

## Getting started

### Prerequisites

### Connection settings

The following settings are required to connect to the API.

| Setting     | Description                            | Mandatory |
| ----------- | -------------------------------------- | --------- |
| AccessToken | The access token to connect to the API | Yes       |
| BaseUrl     | The URL to the API                     | Yes       |

### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _Blue-Dolphin_ to a person in _HelloID_.

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

The account reference is populated with the property `id` property from _Blue-Dolphin_

## Remarks

### SCIM
- **SCIM**: The API is based on the SCIM (System for Cross-domain Identity Management) interface standard.

### API Limitation
- **one call every 250 milliseconds**: The API allows one call every 250 milliseconds per IP address. Exceeding this limit will return an HTTP 429: Too Many Requests response.
If you encounter this issue, try lowering the number of concurrent actions in HelloID.

### Correlation Based on Email Address
- **Email Address Correlation**: The connector relies on email addresses to correlate and match records between systems. Make sure email addresses are accurate and consistent across all systems to prevent issues with data synchronization and matching.
Note: The API does not support filtering on GET calls, so the create action always retrieves all users.

### Enable/Disable Actions
- **SSO**: This connector does not include enable or disable actions, as these are managed through SSO.
- **Import entitlements**: Since enable and disable actions are managed through SSO, the `enabled` property in the **importEntitlements** action should always be set to `$false`.

### Default role
- **alleen lezen (read only)**: Users are assigned the Alleen Lezen (Read-Only) role by default. Any additional roles must be assigned manually.

### Duplicate mappings
- **Different account objects**: The User object returned by the API differs from the one used in the field mapping. As a result, the create, update, and import actions require duplicate mappings to ensure proper data handling.

## Development resources

### API endpoints

The following endpoints are used by the connector

| Endpoint | Description                                          |
| -------- | ---------------------------------------------------- |
| /Users   | Retrieve, create, update and delete user information |

### API documentation

> [!TIP]
> _For more information about the API, please refer to the Documentation of BlueDolphin [documentation](https://support.valueblue.nl/hc/en-us/categories/13253352426140-API-Documentation) pages_.

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]
>  _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com/forum/helloid-connectors/provisioning/5363-helloid-conn-prov-target-blue-dolphin)_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
