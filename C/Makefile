CC = gcc
CFLAGS = -Wall -I.
LIBS = -lncurses

SRCS = main.c globals.c host.c helpers.c E1.c E2.c E3.c E4.c E5.c E6.c E7.c
OBJS = $(SRCS:.c=.o)
TARGET = edisoft

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $(TARGET) $(OBJS) $(LIBS)

%.o: %.c edisoft.h cpu.h
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)

run: $(TARGET)
	./$(TARGET)
