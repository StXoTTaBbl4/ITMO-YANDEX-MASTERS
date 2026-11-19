# Любимый вариант очереди Тимофея — очередь, написанная с использованием связного списка. Помогите ему с реализацией. 
# Очередь должна поддерживать выполнение трёх команд:
# get() — вывести элемент, находящийся в голове очереди, и удалить его. Если очередь пуста, то вывести «error».
# put(x) — добавить число x в очередь
# size() — вывести текущий размер очереди
# Формат ввода
# В первой строке записано количество команд n — целое число, не превосходящее 1000. 
# В каждой из следующих n строк записаны команды по одной строке.
# Формат вывода
# Выведите ответ на каждый запрос по одному в строке.
class Node:
    def __init__(self, value, next_item=None):
        self.value = value
        self.next_item = next_item


class MyQueue:
    def __init__(self):
        self.head = None
        self.tail = None
        self.count = 0

    def put(self, x):
        node = Node(x)
        if self.tail is None:
            self.head = node
            self.tail = node
        else:
            self.tail.next_item = node
            self.tail = node
        self.count += 1

    def get(self):
        if self.head is None:
            print("error")
            return
        value = self.head.value
        self.head = self.head.next_item
        if self.head is None:
            self.tail = None
        self.count -= 1
        print(value)

    def size(self):
        print(self.count)


n = int(input())
queue = MyQueue()

for _ in range(n):
    command = input().strip()
    if command.startswith("put"):
        x = int(command.split()[1])
        queue.put(x)
    elif command == "get":
        queue.get()
    elif command == "size":
        queue.size()
