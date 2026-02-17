// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

var builder = DistributedApplication.CreateBuilder(args);

var root = Path.GetFullPath(Path.Combine(builder.AppHostDirectory, @".."));

if (!Demo.VerifySetup(root, out var token))
{
    return;
}

var options = new
{
    SqlServer = $"qs3-sql-server-{token}",
    SqlVolume = $"qs3-sql-data-{token}",
    SqlDatabase = "TodoDb",
    SqlSchema = Path.Combine(root, "database.sql"),
    DataApi = $"qs3-data-api-{token}",
    DabConfig = Path.Combine(root, "api", "dab-config.json"),
    DabImage = "1.7.83-rc",
    SqlCmdr = $"qs3-sql-cmdr-{token}",
    SqlCmdrImage = "latest",
    WebApp = $"qs3-web-app-{token}",
    WebRoot = Path.Combine(root, "web"),
};

var sqlPassword = builder.AddParameter("sql-password", secret: true);

var sqlServer = builder
    .AddSqlServer(options.SqlServer, sqlPassword)
    .WithDataVolume(options.SqlVolume)
    .WithEnvironment("ACCEPT_EULA", "Y");

var sqlDatabase = sqlServer
    .AddDatabase(options.SqlDatabase)
    .WithCreationScript(File.ReadAllText(options.SqlSchema));

var apiServer = builder
    .AddContainer(options.DataApi, image: "azure-databases/data-api-builder", tag: options.DabImage)
    .WithImageRegistry("mcr.microsoft.com")
    .WithBindMount(source: options.DabConfig, target: "/App/dab-config.json", isReadOnly: true)
    .WithHttpEndpoint(targetPort: 5000, port: 5000, name: "http")
    .WithEnvironment("MSSQL_CONNECTION_STRING", sqlDatabase)
    .WithUrls(context =>
    {
        context.Urls.Clear();
        context.Urls.Add(new() { Url = "/graphql", DisplayText = "GraphQL", Endpoint = context.GetEndpoint("http") });
        context.Urls.Add(new() { Url = "/swagger", DisplayText = "Swagger", Endpoint = context.GetEndpoint("http") });
        context.Urls.Add(new() { Url = "/health", DisplayText = "Health", Endpoint = context.GetEndpoint("http") });
    })
    .WithOtlpExporter()
    .WithParentRelationship(sqlDatabase)
    .WithHttpHealthCheck("/health")
    .WaitFor(sqlDatabase);

var sqlCommander = builder
    .AddContainer(options.SqlCmdr, "jerrynixon/sql-commander", options.SqlCmdrImage)
    .WithImageRegistry("docker.io")
    .WithHttpEndpoint(targetPort: 8080, name: "http")
    .WithEnvironment("ConnectionStrings__db", sqlDatabase)
    .WithUrls(context =>
    {
        context.Urls.Clear();
        context.Urls.Add(new() { Url = "/", DisplayText = "Commander", Endpoint = context.GetEndpoint("http") });
    })
    .WithParentRelationship(sqlDatabase)
    .WithHttpHealthCheck("/health")
    .WaitFor(sqlDatabase);

var webApp = builder
    .AddContainer(options.WebApp, "nginx", "alpine")
    .WithImageRegistry("docker.io")
    .WithBindMount(source: options.WebRoot, target: "/usr/share/nginx/html", isReadOnly: true)
    .WithHttpEndpoint(targetPort: 80, port: 5173, name: "http")
    .WithUrls(context =>
    {
        context.Urls.Clear();
        context.Urls.Add(new() { Url = "/", DisplayText = "Web App", Endpoint = context.GetEndpoint("http") });
    })
    .WaitForCompletion(apiServer);

await builder.Build().RunAsync();
