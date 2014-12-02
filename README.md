nark-berkeley-db-util
=====================

Easy use Berkeley DB on top of nark-serialization

## Quick Start
```c++
#include <nark/bdb_util/dbmap.hpp>
#include <nark/bdb_util/kmapdset.hpp>

	// create DB and insert data
	DbEnv env(0);
	m_env.open("db", DB_CREATE|DB_INIT_MPOOL, 0);
	nark::dbmap<unsigned, SomeType>      id_to_val(&env, "id_to_val");
	nark::kmapdset<dbt_string, SomeType> name_to_vec(&evn, "name_to_vec");
	SomeType val1, val2;
	id_to_val.insert(123, val1);
	name_to_vec.insert("name123", val1);
	name_to_vec.insert("name123", val2);

	// search db
	auto iter1 = id_to_val.find(id);
	if (iter1.exist()) {
		SomeType val = iter1->second;
	}
	auto iter2 = name_to_vec.find(name);
	if (iter2.exist()) {
		std::vector<SomeType> vec;
		// result vector is copied into iter2, use swap is more efficient
		vec.swap(iter.get_mutable().second);
	}
```

In the code snippet, `SomeType` is a type which support [nark-serialization](https://github.com/rockeet/nark-serialization/blob/master/README.md#quick-start).

`dbmap<Key, Value>` is like `std::map<Key, Value>`.
`kmapdset<Key, Value>` is like `std::map<Key, vector<Value> >`

## More
To be written...
