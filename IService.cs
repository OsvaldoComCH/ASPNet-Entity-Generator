using System.Threading.Tasks;
using System.Collections.Generic;

namespace Api.Domain;

public interface IService<T>
    where T : IEntity
{
    public void Add(T entity);
    public Task<T> AddAsync(T entity);

    public T Get(int id);
    public Task<T> GetAsync (int id); 

    public IEnumerable<T> GetAll();
    public Task<IEnumerable<T>> GetAllAsync();

    public IEnumerable<T> GetAll(int page, int limit);
    public Task<IEnumerable<T>> GetAllAsync(int page, int limit);

    public T Update(int id, T entity);
    public Task<T> UpdateAsync(int id, T entity);

    public void Delete(int id);
    public Task DeleteAsync(int id);
}