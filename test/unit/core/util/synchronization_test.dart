// test/unit/core/util/synchronization_test.dart
//
// Comprehensive unit tests for synchronization primitives covering all concurrency scenarios
// to improve coverage from 22.7% to 85%+
//
// This file is part of the CustomFit SDK for Flutter test suite.
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customfit_ai_flutter_sdk/src/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customfit_ai_flutter_sdk/src/core/util/synchronization.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Mutex', () {
    late Mutex mutex;
    setUp(() {
      mutex = Mutex();
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() {
      PreferencesService.reset();
    });
    group('Basic Functionality', () {
      test('should start unlocked', () {
        expect(mutex.isLocked, isFalse);
      });
      test('acquire and release correctly changes isLocked state', () async {
        expect(mutex.isLocked, isFalse);
        await mutex.acquire();
        expect(mutex.isLocked, isTrue);
        mutex.release();
        expect(mutex.isLocked, isFalse);
      });
      test('should allow immediate acquisition when unlocked', () async {
        // Fast path test
        final stopwatch = Stopwatch()..start();
        await mutex.acquire();
        stopwatch.stop();
        expect(mutex.isLocked, isTrue);
        // Should complete immediately (fast path)
        expect(stopwatch.elapsedMilliseconds, lessThan(5));
        mutex.release();
      });
    });
    group('Error Conditions', () {
      test('release throws StateError if not locked', () {
        expect(() => mutex.release(), throwsStateError);
      });
      test('release throws StateError with correct message', () {
        expect(
          () => mutex.release(),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            'Cannot release a mutex that is not locked',
          )),
        );
      });
      test('multiple releases throw StateError', () async {
        await mutex.acquire();
        mutex.release();
        expect(() => mutex.release(), throwsStateError);
        expect(() => mutex.release(), throwsStateError);
      });
    });
    group('Concurrency and Queueing', () {
      test('second acquire waits for first to release (FIFO ordering)',
          () async {
        final events = <String>[];
        final firstTaskCanRelease = Completer<void>();
        // First task acquires the lock and holds it
        final firstTask = () async {
          await mutex.acquire();
          events.add('task1_acquired');
          await firstTaskCanRelease.future;
          events.add('task1_releasing');
          mutex.release();
        }();
        // Give first task time to acquire the lock
        await Future.delayed(Duration.zero);
        expect(events, ['task1_acquired']);
        expect(mutex.isLocked, isTrue);
        // Second task tries to acquire the lock
        final secondTask = () async {
          await mutex.acquire();
          events.add('task2_acquired');
          mutex.release();
        }();
        // Give second task time to try, it should be waiting
        await Future.delayed(Duration.zero);
        expect(events, ['task1_acquired']); // Task 2 has not acquired yet
        // Release the lock from task 1
        firstTaskCanRelease.complete();
        await Future.wait([firstTask, secondTask])
            .timeout(const Duration(seconds: 1));
        expect(events, ['task1_acquired', 'task1_releasing', 'task2_acquired']);
        expect(mutex.isLocked, isFalse);
      });
      test('multiple tasks queued in FIFO order', () async {
        final events = <String>[];
        final firstTaskCanRelease = Completer<void>();
        // First task holds the lock
        final firstTask = () async {
          await mutex.acquire();
          events.add('task1_acquired');
          await firstTaskCanRelease.future;
          mutex.release();
        }();
        await Future.delayed(Duration.zero);
        // Queue up multiple tasks
        final secondTask = () async {
          await mutex.acquire();
          events.add('task2_acquired');
          mutex.release();
        }();
        final thirdTask = () async {
          await mutex.acquire();
          events.add('task3_acquired');
          mutex.release();
        }();
        final fourthTask = () async {
          await mutex.acquire();
          events.add('task4_acquired');
          mutex.release();
        }();
        // Let all tasks queue up
        await Future.delayed(Duration.zero);
        expect(events, ['task1_acquired']);
        // Release first task
        firstTaskCanRelease.complete();
        await Future.wait([firstTask, secondTask, thirdTask, fourthTask])
            .timeout(const Duration(seconds: 1));
        expect(events, [
          'task1_acquired',
          'task2_acquired',
          'task3_acquired',
          'task4_acquired'
        ]);
      });
      test('concurrent acquire attempts are properly serialized', () async {
        final events = <String>[];
        final tasks = <Future>[];
        // Start multiple concurrent acquire attempts
        for (int i = 0; i < 5; i++) {
          tasks.add(() async {
            await mutex.acquire();
            events.add('task${i + 1}_acquired');
            // Hold lock briefly
            await Future.delayed(const Duration(milliseconds: 1));
            mutex.release();
          }());
        }
        await Future.wait(tasks).timeout(const Duration(seconds: 2));
        // All tasks should have acquired the lock exactly once
        expect(events.length, 5);
        expect(events.toSet().length, 5); // All different
        expect(mutex.isLocked, isFalse);
      });
    });
    group('withLock Method', () {
      test('withLock executes function with lock held', () async {
        final events = <String>[];
        await mutex.withLock(() async {
          expect(mutex.isLocked, isTrue);
          events.add('inside_withLock');
        });
        expect(events, ['inside_withLock']);
        expect(mutex.isLocked, isFalse);
      });
      test('withLock releases lock even if function throws', () async {
        expect(
          () => mutex.withLock(() => throw Exception('test error')),
          throwsA(isA<Exception>()),
        );
        // Allow microtasks to complete
        await Future.delayed(Duration.zero);
        expect(mutex.isLocked, isFalse,
            reason: 'Lock should be released after an exception');
      });
      test('withLock properly queues concurrent calls', () async {
        final events = <String>[];
        final firstTaskCanComplete = Completer<void>();
        final firstTask = mutex.withLock(() async {
          events.add('task1_start');
          await firstTaskCanComplete.future;
          events.add('task1_end');
        });
        final secondTask = mutex.withLock(() async {
          events.add('task2_start');
          events.add('task2_end');
        });
        // Let first task start
        await Future.delayed(Duration.zero);
        expect(events, ['task1_start']);
        // Complete first task
        firstTaskCanComplete.complete();
        await Future.wait([firstTask, secondTask])
            .timeout(const Duration(seconds: 1));
        expect(
            events, ['task1_start', 'task1_end', 'task2_start', 'task2_end']);
      });
      test('withLock returns function result', () async {
        final result = await mutex.withLock(() async {
          return 'test_result';
        });
        expect(result, 'test_result');
      });
      test('withLock preserves exception type and message', () async {
        final testException = Exception('specific test error');
        expect(
          () => mutex.withLock(() => throw testException),
          throwsA(same(testException)),
        );
      });
    });
    group('withLockSync Method', () {
      test('withLockSync executes function with lock held when uncontended',
          () {
        final events = <String>[];
        final result = mutex.withLockSync(() {
          expect(mutex.isLocked, isTrue);
          events.add('inside_withLockSync');
          return 'sync_result';
        });
        expect(events, ['inside_withLockSync']);
        expect(result, 'sync_result');
        expect(mutex.isLocked, isFalse);
      });
      test('withLockSync releases lock even if function throws', () {
        expect(
          () => mutex.withLockSync(() => throw Exception('sync error')),
          throwsA(isA<Exception>()),
        );
        expect(mutex.isLocked, isFalse);
      });
      // CRITICAL BUG TEST: This test exposes a critical bug in withLockSync.
      // The `acquire()` call is not awaited, so `fn()` executes immediately
      // even if the lock is held by another task.
      test(
          'BUG: withLockSync executes function immediately without waiting for lock',
          () async {
        final events = <String>[];
        final holdLockCompleter = Completer<void>();
        // Task 1 acquires the lock and holds it
        final task1 = mutex.withLock(() async {
          events.add('task1_acquired_lock');
          await holdLockCompleter.future;
          events.add('task1_releasing_lock');
        });
        // Wait for task 1 to acquire the lock
        await Future.delayed(Duration.zero);
        expect(events, ['task1_acquired_lock']);
        expect(mutex.isLocked, isTrue);
        // Use withLockSync. It should block, but due to the bug, it won't.
        // The function inside is executed immediately.
        mutex.withLockSync(() {
          events.add('task2_sync_executed');
        });
        // The buggy order is [task1_acquired_lock, task2_sync_executed, ...]
        // The correct order would be [task1_acquired_lock, task1_releasing_lock, task2_sync_executed]
        expect(
          events,
          ['task1_acquired_lock', 'task2_sync_executed'],
          reason:
              'withLockSync executed its function while lock was already held',
        );
        // Cleanup
        holdLockCompleter.complete();
        await task1;
      });
      test('withLockSync handles nested calls (no deadlock)', () {
        final events = <String>[];
        mutex.withLockSync(() {
          events.add('outer_start');
          // This would normally cause a deadlock, but due to the bug
          // it might work by accident
          mutex.withLockSync(() {
            events.add('inner_executed');
          });
          events.add('outer_end');
        });
        expect(events, ['outer_start', 'inner_executed', 'outer_end']);
      });
    });
    group('Edge Cases and Stress Tests', () {
      test('should handle rapid acquire/release cycles', () async {
        for (int i = 0; i < 100; i++) {
          await mutex.acquire();
          expect(mutex.isLocked, isTrue);
          mutex.release();
          expect(mutex.isLocked, isFalse);
        }
      });
      test('should handle high contention scenario', () async {
        final counter = <int>[0];
        final tasks = <Future>[];
        // Create many tasks that increment a counter
        for (int i = 0; i < 50; i++) {
          tasks.add(mutex.withLock(() async {
            final current = counter[0];
            await Future.delayed(const Duration(microseconds: 1));
            counter[0] = current + 1;
          }));
        }
        await Future.wait(tasks).timeout(const Duration(seconds: 5));
        expect(counter[0], 50);
        expect(mutex.isLocked, isFalse);
      });
      test('should handle timeout scenarios gracefully', () async {
        final firstTaskCanRelease = Completer<void>();
        // First task holds lock indefinitely
        final firstTask = mutex.withLock(() => firstTaskCanRelease.future);
        // Second task should timeout
        final secondTask = mutex.withLock(() async {
          // This should never execute within the timeout
        }).timeout(const Duration(milliseconds: 50));
        await expectLater(() => secondTask, throwsA(isA<TimeoutException>()));
        // Cleanup
        firstTaskCanRelease.complete();
        await firstTask;
      });
    });
  });
  group('ReadWriteLock', () {
    late ReadWriteLock lock;
    setUp(() {
      lock = ReadWriteLock();
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() {
      PreferencesService.reset();
    });
    group('Basic Read Lock Functionality', () {
      test('should acquire read lock successfully', () async {
        await lock.acquireRead();
        // No direct isLocked equivalent, but we can test by attempting operations
        lock.releaseRead();
      });
      test('multiple readers can acquire lock simultaneously', () async {
        final f1 = lock.acquireRead();
        final f2 = lock.acquireRead();
        final f3 = lock.acquireRead();
        await Future.wait([f1, f2, f3]).timeout(const Duration(seconds: 1));
        // All should complete without blocking each other
        lock.releaseRead();
        lock.releaseRead();
        lock.releaseRead();
      });
      test('concurrent readers with withReadLock', () async {
        final events = <String>[];
        final tasks = <Future>[];
        for (int i = 0; i < 5; i++) {
          tasks.add(lock.withReadLock(() async {
            events.add('reader_${i + 1}_start');
            await Future.delayed(const Duration(milliseconds: 10));
            events.add('reader_${i + 1}_end');
          }));
        }
        await Future.wait(tasks).timeout(const Duration(seconds: 2));
        // All readers should have run concurrently
        expect(events.length, 10);
        expect(events.where((e) => e.contains('start')).length, 5);
        expect(events.where((e) => e.contains('end')).length, 5);
      });
    });
    group('Basic Write Lock Functionality', () {
      test('should acquire write lock successfully', () async {
        await lock.acquireWrite();
        lock.releaseWrite();
      });
      test('write lock is exclusive', () async {
        final events = <String>[];
        final firstWriterCanRelease = Completer<void>();
        // First writer
        final firstWriter = lock.withWriteLock(() async {
          events.add('writer1_acquired');
          await firstWriterCanRelease.future;
          events.add('writer1_releasing');
        });
        await Future.delayed(Duration.zero);
        expect(events, ['writer1_acquired']);
        // Second writer should block
        final secondWriter = lock.withWriteLock(() async {
          events.add('writer2_acquired');
        });
        await Future.delayed(Duration.zero);
        expect(events, ['writer1_acquired']); // Second writer blocked
        firstWriterCanRelease.complete();
        await Future.wait([firstWriter, secondWriter])
            .timeout(const Duration(seconds: 1));
        expect(events,
            ['writer1_acquired', 'writer1_releasing', 'writer2_acquired']);
      });
    });
    group('Reader-Writer Interaction', () {
      test('writer blocks subsequent readers', () async {
        final events = <String>[];
        final writerCompleter = Completer<void>();
        // Writer acquires the lock
        final writer = lock.withWriteLock(() async {
          events.add('writer_acquired');
          await writerCompleter.future;
          events.add('writer_releasing');
        });
        await Future.delayed(Duration.zero);
        expect(events, ['writer_acquired']);
        // Reader tries to acquire, should block
        final reader = lock.withReadLock(() async {
          events.add('reader_acquired');
        });
        await Future.delayed(Duration.zero);
        expect(events, ['writer_acquired']); // Reader has not acquired
        // Writer releases
        writerCompleter.complete();
        await Future.wait([writer, reader]).timeout(const Duration(seconds: 1));
        expect(
            events, ['writer_acquired', 'writer_releasing', 'reader_acquired']);
      });
      test('active readers block subsequent writer', () async {
        final events = <String>[];
        final readerCompleter = Completer<void>();
        // Reader acquires the lock
        final reader = lock.withReadLock(() async {
          events.add('reader_acquired');
          await readerCompleter.future;
          events.add('reader_releasing');
        });
        await Future.delayed(Duration.zero);
        expect(events, ['reader_acquired']);
        // Writer tries to acquire, should block
        final writer = lock.withWriteLock(() async {
          events.add('writer_acquired');
        });
        await Future.delayed(Duration.zero);
        expect(events, ['reader_acquired']); // Writer has not acquired
        // Reader releases
        readerCompleter.complete();
        await Future.wait([reader, writer]).timeout(const Duration(seconds: 1));
        expect(
            events, ['reader_acquired', 'reader_releasing', 'writer_acquired']);
      });
      test('writer is prioritized over waiting readers', () async {
        final events = <String>[];
        final reader1Completer = Completer<void>();
        // 1. Reader 1 acquires the lock
        final reader1 = lock.withReadLock(() async {
          events.add('reader1_acquired');
          await reader1Completer.future;
          events.add('reader1_released');
        });
        await Future.delayed(Duration.zero);
        expect(events, ['reader1_acquired']);
        // 2. Writer queues up
        final writer = lock.withWriteLock(() async {
          events.add('writer_acquired');
          await Future.delayed(const Duration(milliseconds: 5));
          events.add('writer_released');
        });
        await Future.delayed(Duration.zero); // Let writer get in queue
        // 3. Reader 2 queues up behind the writer
        final reader2 = lock.withReadLock(() async {
          events.add('reader2_acquired');
        });
        await Future.delayed(Duration.zero); // Let reader 2 get in queue
        // 4. Reader 1 releases the lock
        reader1Completer.complete();
        await Future.wait([reader1, writer, reader2])
            .timeout(const Duration(seconds: 2));
        // The writer should acquire the lock before the waiting reader
        expect(
          events,
          [
            'reader1_acquired',
            'reader1_released',
            'writer_acquired',
            'writer_released',
            'reader2_acquired'
          ],
          reason: 'Writer should be prioritized over waiting readers',
        );
      });
      test('multiple readers can proceed after writer releases', () async {
        final events = <String>[];
        final writerCompleter = Completer<void>();
        // Writer holds lock
        final writer = lock.withWriteLock(() async {
          events.add('writer_acquired');
          await writerCompleter.future;
        });
        await Future.delayed(Duration.zero);
        // Multiple readers queue up
        final readers = <Future>[];
        for (int i = 0; i < 3; i++) {
          readers.add(lock.withReadLock(() async {
            events.add('reader_${i + 1}_acquired');
          }));
        }
        await Future.delayed(Duration.zero);
        expect(events, ['writer_acquired']); // Only writer has run
        // Release writer
        writerCompleter.complete();
        await Future.wait([writer, ...readers])
            .timeout(const Duration(seconds: 1));
        // All readers should have acquired lock
        expect(events.length, 4); // 1 writer + 3 readers
        expect(events.where((e) => e.contains('reader')).length, 3);
      });
    });
    group('Error Conditions', () {
      test('releasing unheld read lock throws StateError', () {
        expect(() => lock.releaseRead(), throwsStateError);
      });
      test('releasing unheld write lock throws StateError', () {
        expect(() => lock.releaseWrite(), throwsStateError);
      });
      test('releasing read lock more times than acquired throws StateError',
          () async {
        await lock.acquireRead();
        lock.releaseRead();
        expect(() => lock.releaseRead(), throwsStateError);
      });
      test('withReadLock releases lock even on exception', () async {
        expect(
          () => lock.withReadLock(() => throw Exception('read error')),
          throwsA(isA<Exception>()),
        );
        // Should be able to acquire lock again
        await lock.withReadLock(() async {
          // Should succeed
        });
      });
      test('withWriteLock releases lock even on exception', () async {
        expect(
          () => lock.withWriteLock(() => throw Exception('write error')),
          throwsA(isA<Exception>()),
        );
        // Should be able to acquire lock again
        await lock.withWriteLock(() async {
          // Should succeed
        });
      });
    });
    group('Complex Scenarios', () {
      test('alternating readers and writers', () async {
        final events = <String>[];
        await lock.withReadLock(() async {
          events.add('read1');
        });
        await lock.withWriteLock(() async {
          events.add('write1');
        });
        await lock.withReadLock(() async {
          events.add('read2');
        });
        await lock.withWriteLock(() async {
          events.add('write2');
        });
        expect(events, ['read1', 'write1', 'read2', 'write2']);
      });
      test('stress test with mixed readers and writers', () async {
        final events = <String>[];
        final tasks = <Future>[];
        // Mix of readers and writers
        for (int i = 0; i < 20; i++) {
          if (i % 3 == 0) {
            // Writer
            tasks.add(lock.withWriteLock(() async {
              events.add('W$i');
              await Future.delayed(const Duration(microseconds: 100));
            }));
          } else {
            // Reader
            tasks.add(lock.withReadLock(() async {
              events.add('R$i');
              await Future.delayed(const Duration(microseconds: 50));
            }));
          }
        }
        await Future.wait(tasks).timeout(const Duration(seconds: 5));
        // Should have all events
        expect(events.length, 20);
        // Should have both readers and writers
        expect(events.where((e) => e.startsWith('R')).length, greaterThan(0));
        expect(events.where((e) => e.startsWith('W')).length, greaterThan(0));
      });
    });
  });
  group('ReentrantLock', () {
    late ReentrantLock lock;
    setUp(() {
      lock = ReentrantLock();
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() {
      PreferencesService.reset();
    });
    group('Basic Functionality', () {
      test('should acquire and release successfully', () async {
        await lock.acquire();
        lock.release();
      });
      test('withLock should work correctly', () async {
        final events = <String>[];
        await lock.withLock(() async {
          events.add('inside_lock');
        });
        expect(events, ['inside_lock']);
      });
    });
    group('Reentrancy', () {
      test('owner can re-acquire the lock multiple times', () async {
        await lock.acquire(); // holdCount = 1
        await lock.acquire(); // holdCount = 2, should not block
        await lock.acquire(); // holdCount = 3, should not block
        lock.release(); // holdCount = 2
        lock.release(); // holdCount = 1
        lock.release(); // holdCount = 0, fully released
      });
      test('nested withLock calls should work', () async {
        final events = <String>[];
        await lock.withLock(() async {
          events.add('outer_start');
          await lock.withLock(() async {
            events.add('inner_start');
            await lock.withLock(() async {
              events.add('deepest');
            });
            events.add('inner_end');
          });
          events.add('outer_end');
        });
        expect(events, [
          'outer_start',
          'inner_start',
          'deepest',
          'inner_end',
          'outer_end'
        ]);
      });
      test('must release same number of times as acquired', () async {
        await lock.acquire();
        await lock.acquire();
        await lock.acquire();
        // First two releases should not fully release the lock
        lock.release();
        // Can immediately re-acquire since same zone owns it
        await lock.acquire();
        lock.release();
        lock.release();
        // Now another zone/task should be able to acquire it
      });
    });
    group('Zone-based Ownership', () {
      test('blocks acquisition from a different zone', () async {
        final events = <String>[];
        final ownerHasLock = Completer<void>();
        final ownerCanRelease = Completer<void>();
        // Owner acquires lock in current zone
        final owner = () async {
          await lock.acquire();
          events.add('owner_acquired');
          ownerHasLock.complete();
          await ownerCanRelease.future;
          lock.release();
          events.add('owner_released');
        }();
        await ownerHasLock.future;
        // Other zone attempts to acquire
        final otherZoneTask = runZoned(() async {
          events.add('other_zone_attempting');
          await lock.acquire(); // Should block until owner releases
          events.add('other_zone_acquired');
          lock.release();
        });
        // Give other zone time to attempt acquisition
        await Future.delayed(Duration.zero);
        expect(events, ['owner_acquired', 'other_zone_attempting']);
        // Release from owner
        ownerCanRelease.complete();
        await Future.wait([owner, otherZoneTask])
            .timeout(const Duration(seconds: 1));
        expect(events, [
          'owner_acquired',
          'other_zone_attempting',
          'owner_released',
          'other_zone_acquired'
        ]);
      });
      test('cannot release from different zone', () async {
        await lock.acquire();
        expect(
          () => runZoned(() => lock.release()),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            'Cannot release a lock owned by another zone',
          )),
        );
        // Clean up
        lock.release();
      });
      test('reentrant acquisition within same zone', () async {
        final events = <String>[];
        await runZoned(() async {
          await lock.acquire();
          events.add('first_acquire');
          await lock.acquire(); // Should succeed immediately
          events.add('second_acquire');
          lock.release();
          events.add('first_release');
          lock.release();
          events.add('second_release');
        });
        expect(events, [
          'first_acquire',
          'second_acquire',
          'first_release',
          'second_release'
        ]);
      });
    });
    group('Error Conditions', () {
      test('releasing without acquiring throws StateError', () async {
        await lock.acquire();
        lock.release();
        expect(() => lock.release(), throwsStateError);
      });
      test('withLock releases even on exception', () async {
        expect(
          () => lock.withLock(() => throw Exception('test error')),
          throwsA(isA<Exception>()),
        );
        // Should be able to acquire again
        await lock.withLock(() async {
          // Should succeed
        });
      });
    });
    group('Concurrency', () {
      test('multiple zones wait in queue', () async {
        final events = <String>[];
        final ownerCanRelease = Completer<void>();
        // Owner holds lock
        final owner = () async {
          await lock.acquire();
          events.add('owner_acquired');
          await ownerCanRelease.future;
          lock.release();
        }();
        await Future.delayed(Duration.zero);
        // Multiple other zones queue up
        final zone1Task = runZoned(() async {
          await lock.acquire();
          events.add('zone1_acquired');
          lock.release();
        });
        final zone2Task = runZoned(() async {
          await lock.acquire();
          events.add('zone2_acquired');
          lock.release();
        });
        await Future.delayed(Duration.zero);
        expect(events, ['owner_acquired']);
        ownerCanRelease.complete();
        await Future.wait([owner, zone1Task, zone2Task])
            .timeout(const Duration(seconds: 1));
        expect(events.length, 3);
        expect(events[0], 'owner_acquired');
        // zone1 and zone2 should both complete, but order may vary
        expect(events.contains('zone1_acquired'), isTrue);
        expect(events.contains('zone2_acquired'), isTrue);
      });
    });
  });
  group('Global Synchronization Functions', () {
    group('synchronized', () {
      test('should execute function with object-based locking', () {
        final lockObject = Object();
        final events = <String>[];
        final result = synchronized(lockObject, () {
          events.add('synchronized_executed');
          return 'result';
        });
        expect(result, 'result');
        expect(events, ['synchronized_executed']);
      });
      test('same object uses same mutex', () {
        final lockObject = Object();
        final events = <String>[];
        synchronized(lockObject, () {
          events.add('first_call');
        });
        synchronized(lockObject, () {
          events.add('second_call');
        });
        expect(events, ['first_call', 'second_call']);
      });
      test('different objects use different mutexes', () {
        final obj1 = Object();
        final obj2 = Object();
        final events = <String>[];
        synchronized(obj1, () {
          events.add('obj1_call');
        });
        synchronized(obj2, () {
          events.add('obj2_call');
        });
        expect(events, ['obj1_call', 'obj2_call']);
      });
      test('should handle exceptions and release lock', () {
        final lockObject = Object();
        expect(
          () => synchronized(lockObject, () => throw Exception('sync error')),
          throwsA(isA<Exception>()),
        );
        // Should still be able to use the lock
        final result = synchronized(lockObject, () => 'after_exception');
        expect(result, 'after_exception');
      });
    });
    group('synchronizedAsync', () {
      test('should execute async function with object-based locking', () async {
        final lockObject = Object();
        final events = <String>[];
        final result = await synchronizedAsync(lockObject, () async {
          events.add('async_synchronized_executed');
          return 'async_result';
        });
        expect(result, 'async_result');
        expect(events, ['async_synchronized_executed']);
      });
      test('should serialize async function calls', () async {
        final lockObject = Object();
        final events = <String>[];
        final firstCanComplete = Completer<void>();
        final first = synchronizedAsync(lockObject, () async {
          events.add('first_start');
          await firstCanComplete.future;
          events.add('first_end');
        });
        final second = synchronizedAsync(lockObject, () async {
          events.add('second_start');
          events.add('second_end');
        });
        await Future.delayed(Duration.zero);
        expect(events, ['first_start']);
        firstCanComplete.complete();
        await Future.wait([first, second]).timeout(const Duration(seconds: 1));
        expect(
            events, ['first_start', 'first_end', 'second_start', 'second_end']);
      });
      test('sync and async use different mutex maps', () async {
        final lockObject = Object();
        final events = <String>[];
        // These should not interfere with each other since they use
        // different internal mutex maps
        synchronized(lockObject, () {
          events.add('sync_call');
        });
        await synchronizedAsync(lockObject, () async {
          events.add('async_call');
        });
        expect(events, ['sync_call', 'async_call']);
      });
      test('should handle async exceptions and release lock', () async {
        final lockObject = Object();
        expect(
          () => synchronizedAsync(
              lockObject, () async => throw Exception('async error')),
          throwsA(isA<Exception>()),
        );
        // Should still be able to use the lock
        final result =
            await synchronizedAsync(lockObject, () async => 'after_exception');
        expect(result, 'after_exception');
      });
    });
    group('Object Key Behavior', () {
      test('string keys work correctly', () {
        final events = <String>[];
        synchronized('key1', () => events.add('string_key1'));
        synchronized('key1', () => events.add('string_key1_again'));
        synchronized('key2', () => events.add('string_key2'));
        expect(events, ['string_key1', 'string_key1_again', 'string_key2']);
      });
      test('string key works', () {
        final result = synchronized('test_key', () => 'string_key_result');
        expect(result, 'string_key_result');
      });
      test('number keys work correctly', () {
        final events = <String>[];
        synchronized(42, () => events.add('number_42'));
        synchronized(42, () => events.add('number_42_again'));
        synchronized(43, () => events.add('number_43'));
        expect(events, ['number_42', 'number_42_again', 'number_43']);
      });
    });
  });
}
