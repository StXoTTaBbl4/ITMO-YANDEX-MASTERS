# Гоша реализовал структуру данных Дек, максимальный размер которого определяется заданным числом. 
# Методы push_back(x), push_front(x), pop_back(), pop_front() работали корректно. 
# Но, если в деке было много элементов, программа работала очень долго. Дело в том, что не все операции выполнялись за 
# O(1). Помогите Гоше! Напишите эффективную реализацию.
# Внимание: при реализации используйте кольцевой буфер.
# Формат ввода
# В первой строке записано количество команд n — целое число, не превосходящее 100000. 
# Во второй строке записано число m — максимальный размер дека. Он не превосходит 50000. 
# В следующих n строках записана одна из команд:
# push_back(value) – добавить элемент в конец дека. Если в деке уже находится максимальное число элементов, вывести «error».
# push_front(value) – добавить элемент в начало дека. Если в деке уже находится максимальное число элементов, вывести «error».
# pop_front() – вывести первый элемент дека и удалить его. Если дек был пуст, то вывести «error».
# pop_back() – вывести последний элемент дека и удалить его. Если дек был пуст, то вывести «error».
# Value — целое число, по модулю не превосходящее 1000.
# Формат вывода
# Выведите результат выполнения каждой команды на отдельной строке. Для успешных запросов push_back(x) и push_front(x) ничего выводить не надо.
class Deque:
    def __init__(self, max_size):
        self.max_size = max_size
        self.data = [None] * max_size
        self.head = 0
        self.tail = 0
        self.count = 0

    def push_back(self, x):
        if self.count == self.max_size:
            print("error")
            return
        self.data[self.tail] = x
        self.tail = (self.tail + 1) % self.max_size
        self.count += 1

    def push_front(self, x):
        if self.count == self.max_size:
            print("error")
            return
        self.head = (self.head - 1) % self.max_size
        self.data[self.head] = x
        self.count += 1

    def pop_front(self):
        if self.count == 0:
            print("error")
            return
        value = self.data[self.head]
        self.data[self.head] = None
        self.head = (self.head + 1) % self.max_size
        self.count -= 1
        print(value)

    def pop_back(self):
        if self.count == 0:
            print("error")
            return
        self.tail = (self.tail - 1) % self.max_size
        value = self.data[self.tail]
        self.data[self.tail] = None
        self.count -= 1
        print(value)


n = int(input())
m = int(input())

deque = Deque(m)

for _ in range(n):
    command = input().strip()
    if command.startswith("push_back"):
        x = int(command.split()[1])
        deque.push_back(x)
    elif command.startswith("push_front"):
        x = int(command.split()[1])
        deque.push_front(x)
    elif command == "pop_front":
        deque.pop_front()
    elif command == "pop_back":
        deque.pop_back()
