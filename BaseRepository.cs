using Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Core;

public class BaseRepository<T>(DbContext context) : IRepository<T>
    where T : IEntity
{
    protected DbContext Context { get; set; } = context;
    protected DbSet<T> Entities = context.Set<T>();

    public virtual T Add(T entity)
    {
        return Entities.Add(entity).Entity;
    }

    public virtual async Task<T> AddAsync(T entity)
    {
        var result = await Entities.AddAsync(entity);
        return result.Entity;
    }
    public virtual IQueryable<T> Get()
    {
        return Entities;
    }

    public virtual IQueryable<T> GetAllNoTracking()
    {
        return Entities.AsNoTracking();
    }

    public virtual void Remove(T obj)
    {
        Entities.Remove(obj);
    }

    public void Detach(T obj)
    {
        Context.Entry(obj).State = EntityState.Detached;
    }

    public virtual void Save()
    {
        Context.SaveChanges();
    }

    public virtual Task SaveAsync()
    {
        return Context.SaveChangesAsync();
    }

    public virtual T Update(T obj)
    {
        return Entities.Update(obj).Entity;
    }
}