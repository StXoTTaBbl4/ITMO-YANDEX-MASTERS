# Реализуйте класс StackMaxEffective, поддерживающий операцию определения максимума среди элементов в стеке. 
# Сложность операции должна быть O(1). 
# Для пустого стека операция должна возвращать None. При этом push(x) и pop() также должны выполняться за константное время.
# Формат ввода
# В первой строке записано одно число — количество команд, оно не превосходит 100000. 
# Далее идут команды по одной в строке. Команды могут быть следующих видов:
# push(x) — добавить число x в стек. Число x не превышает 10^5
# pop() — удалить число с вершины стека;
# get_max() — напечатать максимальное число в стеке;
# top() — напечатать число с вершины стека;
# Если стек пуст, при вызове команды get_max нужно напечатать «None», для команды pop и top — «error».

# Формат вывода
# Для каждой команды get_max() напечатайте результат её выполнения. 
# Если стек пустой, для команды get_max() напечатайте «None». 
# Если происходит удаление из пустого стека — напечатайте «error».
class StackMaxEffective:
    def __init__(self):
        self.items = []

    def push(self, x):
        if self.items:
            current_max = max(x, self.items[-1][1])
        else:
            current_max = x
        self.items.append((x, current_max))

    def pop(self):
        if not self.items:
            print("error")
            return
        self.items.pop()

    def get_max(self):
        if not self.items:
            print("None")
        else:
            print(self.items[-1][1])

    def top(self):
        if not self.items:
            print("error")
        else:
            print(self.items[-1][0])


def main():
    n = int(input())
    stack = StackMaxEffective()

    for _ in range(n):
        command = input().strip()
        if command.startswith("push"):
            x = int(command.split()[1])
            stack.push(x)
        elif command == "pop":
            stack.pop()
        elif command == "get_max":
            stack.get_max()
        elif command == "top":
            stack.top()


main()
