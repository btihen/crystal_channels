# channels

This uses channels back and forth between users and chat rooms.

## CODE

- **src_01_direct** - users directly messaging each other over channels 1 to 1
- **src_02_chat** - users subscribe to a chat room - now we can do 1 to many over channels.  Now Fibers are interesting.  With one thread (& one output window its all readable).  With multi-threading (& one output window) - output is no longer readable.
- **src_03_parellelism** - **TOTO:** write chat with each user having separate sessions / windows so outputs don't get jumbled

**Questions**
- how to I stop program AFTER all thread and fibers are finished!

## Installation

**1 thread compile**
crystal build --release src/chat_channels.cr -o ./chat_channels

**compile with parellelism**
crystal build --release -Dpreview_mt  src/chat_channels.cr -o ./chat_channels

## Usage

**run in one big thread**
./chat_channels
or
crystal run src/chat_channels.cr

**run in parrell**
time ./channels  # default workers is 4
time CRYSTAL_WORKERS=2 ./channels
time CRYSTAL_WORKERS=4 ./channels
_(very hard to read -without each user having their own tcp-session / or window) - messages get all jumbled in one output window)_
