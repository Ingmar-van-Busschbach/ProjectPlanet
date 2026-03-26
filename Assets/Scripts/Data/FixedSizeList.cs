using System.Collections.Generic;

//This allows us to perform Add() to an array, as long as we keep it to a fixed length.
public class FixedSizeList<T>
{
    public T[] items;
    public int nextIndex;

    public FixedSizeList(int size)
    {
        items = new T[size];
    }

    public void Add(T item)
    {
        items[nextIndex] = item;
        nextIndex++;
    }

    public void AddRange(IEnumerable<T> items)
    {
        foreach (var item in items)
        {
            Add(item);
        }
    }
}
