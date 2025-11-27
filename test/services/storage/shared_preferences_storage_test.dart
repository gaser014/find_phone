import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:find_phone/services/storage/shared_preferences_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesStorage', () {
    late SharedPreferencesStorage storage;

    setUp(() async {
      // Set up mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      storage = SharedPreferencesStorage(keyPrefix: 'test_');
      await storage.init();
    });

    group('store and retrieve', () {
      test('stores and retrieves string values', () async {
        await storage.store('testKey', 'testValue');
        final result = await storage.retrieve('testKey');
        expect(result, equals('testValue'));
      });

      test('stores and retrieves integer values', () async {
        await storage.store('intKey', 42);
        final result = await storage.retrieve('intKey');
        expect(result, equals(42));
      });

      test('stores and retrieves double values', () async {
        await storage.store('doubleKey', 3.14);
        final result = await storage.retrieve('doubleKey');
        expect(result, equals(3.14));
      });

      test('stores and retrieves boolean values', () async {
        await storage.store('boolKey', true);
        final result = await storage.retrieve('boolKey');
        expect(result, equals(true));
      });

      test('stores and retrieves string list values', () async {
        final list = ['a', 'b', 'c'];
        await storage.store('listKey', list);
        final result = await storage.retrieve('listKey');
        expect(result, equals(list));
      });

      test('returns null for non-existent key', () async {
        final result = await storage.retrieve('nonExistent');
        expect(result, isNull);
      });
    });

    group('typed accessors', () {
      test('getString returns string value', () async {
        await storage.store('strKey', 'hello');
        final result = await storage.getString('strKey');
        expect(result, equals('hello'));
      });

      test('getString returns default for missing key', () async {
        final result = await storage.getString('missing', defaultValue: 'default');
        expect(result, equals('default'));
      });

      test('getInt returns integer value', () async {
        await storage.store('intKey', 100);
        final result = await storage.getInt('intKey');
        expect(result, equals(100));
      });

      test('getDouble returns double value', () async {
        await storage.store('dblKey', 2.718);
        final result = await storage.getDouble('dblKey');
        expect(result, equals(2.718));
      });

      test('getBool returns boolean value', () async {
        await storage.store('boolKey', false);
        final result = await storage.getBool('boolKey');
        expect(result, equals(false));
      });

      test('getStringList returns list value', () async {
        final list = ['x', 'y', 'z'];
        await storage.store('listKey', list);
        final result = await storage.getStringList('listKey');
        expect(result, equals(list));
      });
    });

    group('JSON storage', () {
      test('stores and retrieves map as JSON', () async {
        final map = {'name': 'test', 'value': 123};
        await storage.store('mapKey', map);
        final result = await storage.getMap('mapKey');
        expect(result, equals(map));
      });
    });

    group('delete operations', () {
      test('deletes existing key', () async {
        await storage.store('toDelete', 'value');
        expect(await storage.containsKey('toDelete'), isTrue);
        
        await storage.delete('toDelete');
        expect(await storage.containsKey('toDelete'), isFalse);
      });

      test('clearAll removes all keys with prefix', () async {
        await storage.store('key1', 'value1');
        await storage.store('key2', 'value2');
        
        await storage.clearAll();
        
        expect(await storage.containsKey('key1'), isFalse);
        expect(await storage.containsKey('key2'), isFalse);
      });
    });

    group('key operations', () {
      test('containsKey returns true for existing key', () async {
        await storage.store('exists', 'value');
        expect(await storage.containsKey('exists'), isTrue);
      });

      test('containsKey returns false for non-existent key', () async {
        expect(await storage.containsKey('notExists'), isFalse);
      });

      test('getAllKeys returns all stored keys', () async {
        await storage.store('a', 1);
        await storage.store('b', 2);
        await storage.store('c', 3);
        
        final keys = await storage.getAllKeys();
        expect(keys, containsAll(['a', 'b', 'c']));
      });
    });

    group('readAll', () {
      test('returns all stored data', () async {
        await storage.store('str', 'hello');
        await storage.store('num', 42);
        
        final all = await storage.readAll();
        expect(all['str'], equals('hello'));
        expect(all['num'], equals(42));
      });
    });

    group('null handling', () {
      test('storing null removes the key', () async {
        await storage.store('key', 'value');
        expect(await storage.containsKey('key'), isTrue);
        
        await storage.store('key', null);
        expect(await storage.containsKey('key'), isFalse);
      });
    });
  });
}
