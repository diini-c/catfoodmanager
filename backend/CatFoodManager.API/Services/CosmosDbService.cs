using Microsoft.Azure.Cosmos;
using CatFoodManager.API.Models;

namespace CatFoodManager.API.Services;

public interface ICosmosDbService
{
    // Users
    Task<User?> GetUserByIdAsync(string id);
    Task<User?> GetUserByEmailAsync(string email);
    Task<User> CreateUserAsync(User user);
    Task<User> UpdateUserAsync(User user);
    Task<List<User>> GetUsersByHouseholdAsync(string householdId);

    // Households
    Task<Household?> GetHouseholdByIdAsync(string id);
    Task<Household?> GetHouseholdByInviteCodeAsync(string inviteCode);
    Task<Household> CreateHouseholdAsync(Household household);
    Task<Household> UpdateHouseholdAsync(Household household);

    // Cats
    Task<Cat?> GetCatByIdAsync(string householdId, string catId);
    Task<List<Cat>> GetCatsByHouseholdAsync(string householdId);
    Task<Cat> CreateCatAsync(Cat cat);
    Task<Cat> UpdateCatAsync(Cat cat);
    Task DeleteCatAsync(string householdId, string catId);

    // Feeding Logs
    Task<List<FeedingLog>> GetFeedingLogsByHouseholdAsync(string householdId, int limit = 50);
    Task<List<FeedingLog>> GetFeedingLogsByCatAsync(string householdId, string catId, int limit = 20);
    Task<FeedingLog> CreateFeedingLogAsync(FeedingLog log);

    // Messages
    Task<List<HouseholdMessage>> GetMessagesByHouseholdAsync(string householdId, int limit = 50);
    Task<HouseholdMessage> CreateMessageAsync(HouseholdMessage message);
    Task DeleteMessageAsync(string householdId, string messageId);
}

public class CosmosDbService : ICosmosDbService
{
    private readonly Container _container;

    public CosmosDbService(CosmosClient cosmosClient, IConfiguration configuration)
    {
        var databaseName = configuration["CosmosDb:DatabaseName"]!;
        var containerName = configuration["CosmosDb:ContainerName"]!;
        _container = cosmosClient.GetContainer(databaseName, containerName);
    }

    // Users
    public async Task<User?> GetUserByIdAsync(string id)
    {
        try
        {
            var response = await _container.ReadItemAsync<User>(id, new PartitionKey("user"));
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    public async Task<User?> GetUserByEmailAsync(string email)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.type = 'user' AND c.email = @email")
            .WithParameter("@email", email.ToLowerInvariant());

        var iterator = _container.GetItemQueryIterator<User>(query);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            var user = response.FirstOrDefault();
            if (user != null) return user;
        }
        return null;
    }

    public async Task<User> CreateUserAsync(User user)
    {
        user.Email = user.Email.ToLowerInvariant();
        var response = await _container.CreateItemAsync(user, new PartitionKey(user.PartitionKey));
        return response.Resource;
    }

    public async Task<User> UpdateUserAsync(User user)
    {
        var response = await _container.UpsertItemAsync(user, new PartitionKey(user.PartitionKey));
        return response.Resource;
    }

    public async Task<List<User>> GetUsersByHouseholdAsync(string householdId)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.type = 'user' AND c.householdId = @householdId")
            .WithParameter("@householdId", householdId);

        var users = new List<User>();
        var iterator = _container.GetItemQueryIterator<User>(query);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            users.AddRange(response);
        }
        return users;
    }

    // Households
    public async Task<Household?> GetHouseholdByIdAsync(string id)
    {
        try
        {
            var response = await _container.ReadItemAsync<Household>(id, new PartitionKey($"household_{id}"));
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    public async Task<Household?> GetHouseholdByInviteCodeAsync(string inviteCode)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.type = 'household' AND c.inviteCode = @code")
            .WithParameter("@code", inviteCode.ToUpperInvariant());

        var iterator = _container.GetItemQueryIterator<Household>(query);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            var household = response.FirstOrDefault();
            if (household != null) return household;
        }
        return null;
    }

    public async Task<Household> CreateHouseholdAsync(Household household)
    {
        var response = await _container.CreateItemAsync(household, new PartitionKey(household.PartitionKey));
        return response.Resource;
    }

    public async Task<Household> UpdateHouseholdAsync(Household household)
    {
        var response = await _container.UpsertItemAsync(household, new PartitionKey(household.PartitionKey));
        return response.Resource;
    }

    // Cats
    public async Task<Cat?> GetCatByIdAsync(string householdId, string catId)
    {
        try
        {
            var response = await _container.ReadItemAsync<Cat>(catId, new PartitionKey($"household_{householdId}"));
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    public async Task<List<Cat>> GetCatsByHouseholdAsync(string householdId)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.type = 'cat' AND c.householdId = @householdId ORDER BY c.name")
            .WithParameter("@householdId", householdId);

        var cats = new List<Cat>();
        var iterator = _container.GetItemQueryIterator<Cat>(query);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            cats.AddRange(response);
        }
        return cats;
    }

    public async Task<Cat> CreateCatAsync(Cat cat)
    {
        cat.PartitionKey = $"household_{cat.HouseholdId}";
        var response = await _container.CreateItemAsync(cat, new PartitionKey(cat.PartitionKey));
        return response.Resource;
    }

    public async Task<Cat> UpdateCatAsync(Cat cat)
    {
        cat.UpdatedAt = DateTime.UtcNow;
        var response = await _container.UpsertItemAsync(cat, new PartitionKey(cat.PartitionKey));
        return response.Resource;
    }

    public async Task DeleteCatAsync(string householdId, string catId)
    {
        await _container.DeleteItemAsync<Cat>(catId, new PartitionKey($"household_{householdId}"));
    }

    // Feeding Logs
    public async Task<List<FeedingLog>> GetFeedingLogsByHouseholdAsync(string householdId, int limit = 50)
    {
        var query = new QueryDefinition($"SELECT TOP {limit} * FROM c WHERE c.type = 'feedingLog' AND c.householdId = @householdId ORDER BY c.fedAt DESC")
            .WithParameter("@householdId", householdId);

        var logs = new List<FeedingLog>();
        var iterator = _container.GetItemQueryIterator<FeedingLog>(query);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            logs.AddRange(response);
        }
        return logs;
    }

    public async Task<List<FeedingLog>> GetFeedingLogsByCatAsync(string householdId, string catId, int limit = 20)
    {
        var query = new QueryDefinition($"SELECT TOP {limit} * FROM c WHERE c.type = 'feedingLog' AND c.householdId = @householdId AND c.catId = @catId ORDER BY c.fedAt DESC")
            .WithParameter("@householdId", householdId)
            .WithParameter("@catId", catId);

        var logs = new List<FeedingLog>();
        var iterator = _container.GetItemQueryIterator<FeedingLog>(query);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            logs.AddRange(response);
        }
        return logs;
    }

    public async Task<FeedingLog> CreateFeedingLogAsync(FeedingLog log)
    {
        log.PartitionKey = $"household_{log.HouseholdId}";
        var response = await _container.CreateItemAsync(log, new PartitionKey(log.PartitionKey));
        return response.Resource;
    }

    // Messages
    public async Task<List<HouseholdMessage>> GetMessagesByHouseholdAsync(string householdId, int limit = 50)
    {
        var query = new QueryDefinition($"SELECT TOP {limit} * FROM c WHERE c.type = 'message' AND c.householdId = @householdId ORDER BY c.isPinned DESC, c.createdAt DESC")
            .WithParameter("@householdId", householdId);

        var messages = new List<HouseholdMessage>();
        var iterator = _container.GetItemQueryIterator<HouseholdMessage>(query);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            messages.AddRange(response);
        }
        return messages;
    }

    public async Task<HouseholdMessage> CreateMessageAsync(HouseholdMessage message)
    {
        message.PartitionKey = $"household_{message.HouseholdId}";
        var response = await _container.CreateItemAsync(message, new PartitionKey(message.PartitionKey));
        return response.Resource;
    }

    public async Task DeleteMessageAsync(string householdId, string messageId)
    {
        await _container.DeleteItemAsync<HouseholdMessage>(messageId, new PartitionKey($"household_{householdId}"));
    }
}
