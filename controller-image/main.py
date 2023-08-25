#!/usr/bin/env python -u
import eks_run
import threading

def multi_thread(thread_count: int):
    print(f"Starting {thread_count} threads...")
    t = []
    for i in range(0, thread_count):
        t.append(
            threading.Thread(target=eks_run.runMain, name=f'Thread-{i}')
        )
    for thread in t:
        thread.start()
    for thread in t:
        thread.join()
    print('thread %s ended.' % threading.current_thread().name)

if __name__ == "__main__":
    thread_count = 10;
    multi_thread(thread_count);
