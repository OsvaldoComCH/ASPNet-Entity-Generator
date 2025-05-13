using System.Linq;
using Microsoft.EntityFrameworkCore;
using Api.Domain;

namespace Api.Core;

public class BaseService<T>(BaseRepository<T> repository) : IService<T>
    where T : IEntity
{
    protected readonly IRepository<T> Repository = repository;

    public virtual void Add(T entity)
    {
        var obj = Repository
            .GetAllNoTracking()
            .SingleOrDefault(item => item.Id == entity.Id);

        if(obj != null)
        {
            throw new Exception("Object already exists");
        }

        Repository.Add(entity);
        Repository.Save();
    }

    public virtual async Task<T> AddAsync(T entity)
    {
        var obj = await Repository
            .GetAllNoTracking()
            .SingleOrDefaultAsync(item => item.Id == entity.Id);

        if(obj != null)
        {
            throw new Exception("Object already exists");
        }

        obj = Repository.Add(entity);
        await Repository.SaveAsync();
        return obj;
    }

    public virtual T Get(int id)
    {
        var obj = Repository
            .GetAllNoTracking()
            .SingleOrDefault(item => item.Id == id);

        if(obj == null)
        {
            throw new Exception("Object does not exist");
        }

        return obj;
    }

    public virtual async Task<T> GetAsync(int id)
    {
        var obj = await Repository
            .GetAllNoTracking()
            .SingleOrDefaultAsync(item => item.Id == id);

        if(obj is null)
        {
            throw new Exception("Object does not exist");
        }

        return obj;
    }

    public IEnumerable<T> GetAll()
    {
        return Repository.GetAllNoTracking().ToList();
    }

    public async Task<IEnumerable<T>> GetAllAsync()
    {
        return await Repository.GetAllNoTracking().ToListAsync();
    }

    public IEnumerable<T> GetAll(int page, int limit)
    {
        return Repository.GetAllNoTracking().Skip(page * limit).Take(limit).ToList();
    }

    public async Task<IEnumerable<T>> GetAllAsync(int page, int limit)
    {
        return await Repository.GetAllNoTracking().Skip(page * limit).Take(limit).ToListAsync();
    }

    public virtual T Update(int id, T entity)
    {
        var obj = Repository
            .GetAllNoTracking()
            .SingleOrDefault(item => item.Id == id);

        if(obj == null)
        {
            throw new Exception("Object does not exist");
        }

        var updated = Repository.Update(entity);
        Repository.Save();
        Repository.Detach(updated);
        return updated;
    }   

    public virtual async Task<T> UpdateAsync(int id, T entity)
    {
        var obj = await Repository
            .GetAllNoTracking()
            .SingleOrDefaultAsync(item => item.Id == id);

        if(obj == null)
        {
            throw new Exception("Object does not exist");
        }

        var updated = Repository.Update(entity);

        await Repository.SaveAsync();
        Repository.Detach(updated);
        return updated;
    }
    
    public virtual void Delete(int id)
    {
        var obj = Repository
            .GetAllNoTracking()
            .SingleOrDefault(item => item.Id == id);

        if(obj == null)
        {
            throw new Exception("Object does not exist");
        }

        Repository.Remove(obj);
        Repository.Save();
    }

    public virtual async Task DeleteAsync(int id)
    {
        var obj = await Repository
            .GetAllNoTracking()
            .SingleOrDefaultAsync(item => item.Id == id);

        if(obj == null)
        {
            throw new Exception("Object does not exist");
        }

        Repository.Remove(obj);
        await Repository.SaveAsync();
    }
}