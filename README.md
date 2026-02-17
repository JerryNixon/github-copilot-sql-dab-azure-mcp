# Data API Builder Quickstarts

Four progressive quickstarts that teach Data API Builder (DAB) from zero auth to full row-level security. Each quickstart is self-contained and can run independently.

## Quickstarts

| # | Name | What It Adds | User → Web | Web → API | API → SQL (Azure) |
|---|------|-------------|------------|-----------|-------------------|
| [1](quickstart1/) | **Zero Auth** | Anonymous access | None | None | SQL Auth |
| [2](quickstart2/) | **Managed Identity** | Passwordless DB | None | None | SAMI |
| [3](quickstart3/) | **User Auth** | Entra ID login | Entra ID | Bearer token | SAMI |
| [4](quickstart4/) | **Row-Level Security** | Per-user data | Entra ID | Bearer token | SAMI + Policy |

## Start Here

Pick [Quickstart 1](quickstart1/) and work forward. Each builds on the previous one.

## Prerequisites

- [.NET 10+ SDK](https://dotnet.microsoft.com/download) with [Aspire workload](https://learn.microsoft.com/dotnet/aspire/fundamentals/setup-tooling)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (QS3/QS4 only)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) (for Azure deployment)

## License

Demonstration project for learning purposes.
