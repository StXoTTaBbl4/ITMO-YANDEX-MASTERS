# Нужно реализовать класс StackMax, который поддерживает операцию определения максимума среди всех элементов в стеке. 
# Класс должен поддерживать операции push(x), где x – целое число, pop() и get_max().
# Формат ввода
# В первой строке записано одно число n — количество команд, которое не превосходит 10000. 
# В следующих n строках идут команды. Команды могут быть следующих видов:
# push(x) — добавить число x в стек. Число x не превышает 10^5
# pop() — удалить число с вершины стека;
# get_max() — напечатать максимальное число в стеке;
# Если стек пуст, при вызове команды get_max() нужно напечатать «None», для команды pop() — «error».

# Формат вывода
# Для каждой команды get_max() напечатайте результат её выполнения.
# Если стек пустой, для команды get_max() напечатайте «None».
# Если происходит удаление из пустого стека — напечатайте «error».
class StackMax:
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


def main():
    n = int(input())
    stack = StackMax()

    for _ in range(n):
        command = input().strip()
        if command.startswith("push"):
            x = int(command.split()[1])
            stack.push(x)
        elif command == "pop":
            stack.pop()
        elif command == "get_max":
            stack.get_max()


main()
