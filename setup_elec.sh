#!/usr/bin/env bash

#This is just to make sure you are running this script in the same folder
#as the rest of the code for the project
check_files_exist() {
    for file in main.c robot.c formulas.c; do
        if [[ ! -f $file ]]; then
            echo "Error: $file not found in the current directory."
            echo "Please move this script to the directory containing $file and try again."
            exit 1
        fi
    done
}
#This function just installs the depencies you need and associated libraries
#it only currently accounts for 3 package managers. Might extend might no who knows
install_sdl2_linux() {
    # Detect package manager.

    if [[ $(command -v apt) ]]; then
        sudo apt update
        sudo apt install -y libsdl2-dev libsdl2-gfx-dev gcc build-essential
    elif [[ $(command -v dnf) ]]; then
        sudo dnf install -y SDL2-devel SDL2_gfx-devel gcc
    elif [[ $(command -v pacman) ]]; then
        sudo pacman -Syu --needed sdl2 sdl2_gfx gcc
    else
        echo "Error: Supported package manager not found. Please install SDL2 and SDL2_gfx manually."
        exit 1
    fi
    sed -i 's/sdl.h/SDL2\/SDL.h/g' {*.c,*.h}
    sed -i 's/SDL2_gfx-1.0.1\/SDL2_gfxPrimitives.h/SDL2_gfxPrimitives.h/g' {*.c,*.h}
    #the headers for the target files will be edited
}

#This function ensures that the sdl12 config file is in your enviroment path, if it isnt it will put it
#if it cant put it, it will tell you as much and will make a note in the error.log file
sdl2_config_path() {

    if [[  $(command -v sdl12) ]]; then
        echo "sdl2-config not found in PATH. Trying to locate and add to PATH for Mac"
        brew_sdl2_path=$(brew --prefix sdl2)/bin)
        if [[ -x "$brew_sdl2_path/sdl12-config" ]]; then
            echo "Sdl config is in your path so it doesnt seem to be the issue"
            if [[ $SHELL == "/bin/zsh" ]]; then
                echo "export PATH=\$PATH:$brew_sdl2_path" >> ~/.zshrc
                source ~./zshrc
            elif [[ $SHELL == "/bin/bash" ]]; then
                echo "export PATH=\$PATH:$brew_sdl2_path" >> ~/.bash_profile
                source ~/.bash_profile
            fi
            return 0
        fi

        echo "Error: Could not locate sdl12-config."
        echo "Check the error and compile error logs for probably more details"
    else
        echo "Guess its already in your path"
   fi
}

#We just look for if you have gcc, if its an old version you should prolly update
#it will download if it doesnt find it, and offers you an upgrade option
check_gcc_linux() {
    if [[ $(command -v gcc) == "" ]]; then
        echo "GCC not found. Installing..."
        if [[ $(command -v apt) ]]; then
            sudo apt install -y gcc build-essential
        elif [[ $(command -v dnf) ]]; then
            sudo dnf install -y gcc
        elif [[ $(command -v pacman) ]]; then
            sudo pacman -Syu --needed gcc
        else
            echo "Error: Supported package manager not found. Please install GCC manually."
            exit 1
        fi
    else
        echo "GCC found. Would you like to upgrade? (y/n)"
        read -r response
        if [[ "$response" == "y" ]]; then
            if [[ $(command -v apt) ]]; then
                sudo apt update
                sudo apt upgrade -y gcc
            elif [[ $(command -v dnf) ]]; then
                sudo dnf upgrade -y gcc
            elif [[ $(command -v pacman) ]]; then
                sudo pacman -Syu gcc
            fi
        fi
    fi
}

#This function does the same but for mac os instead of linux.
#It will keep in mind intel and m1/m2 based macs. Or I hope it does

install_mac() {
    # Check if Homebrew is installed.
    if [[ $(command -v brew) == "" ]]; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    #check if sdl2 and sdl2_gfx are installed
    if [[ $(brew list | grep -c "sdl2") == 0 ]]; then

        echo "Seems sdl2 and sdl2_gfx are already installed"
        echo "Installing SDL2 and SDL2_gfx..."
        brew install sdl2 sdl2_gfx
    else
        echo "Seems sdl2 and sdl2_gfx are already installed"
    fi
    # Install SDL2 libraries.
    #echo "Installing SDL2 and SDL2_gfx..."
    #brew install sdl2 sdl2_gfx

    # Check if gcc is installed.
    if [[ $(command -v gcc) == "" ]]; then
        echo "GCC not found. Installing..."
        brew install gcc
    else
        read -p "GCC is already installed. Do you want to upgrade it? (y/n) " choice
        if [[ $choice == "y" ]]; then
            brew upgrade gcc
        fi
    fi

    # Setting environment variables.
    echo "Setting environment variables..."
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'export CPATH=/opt/homebrew/include' >> ~/.zshrc
        echo 'export LIBRARY_PATH=/opt/homebrew/lib' >> ~/.zshrc
    else
        echo 'export CPATH=/usr/local/include' >> ~/.zshrc
        echo 'export LIBRARY_PATH=/usr/local/lib' >> ~/.zshrc
    fi
    source ~/.zshrc

    # Update include statements in the files for Mac.
    sed -i '' 's/#include "sdl.h"/#include "SDL2\/SDL.h"/g' main.c robot.h wall.h
    sed -i '' 's/#include "SDL2_gfx-1.0.1\/SDL2_gfxPrimitives.h"/#include "SDL2\/SDL2_gfxPrimitives.h"/g' main.c robot.h wall.h
}

#Here we see what the operating system its run in.
#Calls the relevant functions.
if [[ "$(uname)" == "Linux" ]]; then
    check_files_exist
    install_sdl2_linux
    check_gcc_linux
    #sdl2_flags=$(sdl2-config --cflags --libs)
    compile_cmd="gcc wall.c formulas.c robot.c main.c -o main $(echo -n $(sdl2-config --cflags --libs)) -lm"

#if its mac, do mac specific stuff.
#The functions for mac are the ones checking for intel/arm   
elif [[ "$(uname)" == "Darwin" ]]; then
    install_mac
    check_files_exist
    sdl2_config_path
    compile_cmd="gcc wall.c formulas.c robot.c main.c -o main -lSDL2"
fi
#Here you are offered the chance to alias the commands for compiling
echo "WARNING:If you want an alias, make sure its distiinguashed, like gcc_elec for example"
echo "" #note bash is weird in different platforms, only way to garuntee newline consistently
read -p "'Do you want to create an alias for compiling the project? (y/n)'" choice

if [[ $choice == "y" ]]; then
    read -p "Enter the alias (without spaces): " alias_name
    while [[ $alias_name =~ \s ]]; do
        echo "Alias contains spaces. Please enter again."
        read -p "Enter the alias (without spaces): " alias_name
    done
  if [[ "$(uname)" == "Linux" ]]; then
    # Add alias to .bashrc (or any other appropriate file for Linux)
    echo "alias $alias_name='$compile_cmd'" >> ~/.bashrc
    source ~/.bashrc
  elif [[ "$(uname)" == "Darwin" ]]; then
    # Add alias to .bash_profile or .zshrc for macOS
   if [[ $SHELL == "/bin/zsh" ]]; then
        echo "alias $alias_name='$compile_cmd'" >> ~/.zshrc
        source ~/.zshrc
    else
        echo "alias $alias_name='$compile_cmd'" >> ~/.bash_profile
        source ~/.bash_profile
        fi
    fi
fi

#Here we look for the dependencies for the project
#Mainly sdl2 and sdl2_gfx. We will use the absolute path for
#make file
locate_dependencies(){

    echo "I guess this is the last ditch attempt before you gotta ask on ed"
    FD_CMD="fd"  # Set default to "fd"
    SDL2_HEADER_PATH=""
    SDL2_LIB_PATH=""

    # If "fdfind" is available, then use it
    if [[ $(command -v fdfind) ]]; then
        FD_CMD="fdfind"
fi
    # macOS
if [[ $is_mac -eq 0 ]]; then
        SDL2_HEADER_PATH=$($FD_CMD 'SDL.h' /usr/local/include 2>/dev/null | head -1 | xargs dirname)

    # apt (Debian/Ubuntu etc.)
    elif [[ $is_apt -eq 0 ]]; then
        FD_CMD="fdfind"
        SDL2_HEADER_PATH=$($FD_CMD 'SDL.h' /usr/include 2>/dev/null | head -1 | xargs dirname)
        SDL2_LIB_PATH=$($FD_CMD --type d 'lib.*SDL2' /usr/lib 2>/dev/null | head -1)

    # dnf (Fedora)
    elif [[ $is_dnf -eq 0 ]]; then
        SDL2_HEADER_PATH=$($FD_CMD 'SDL.h' /usr/include 2>/dev/null | head -1 | xargs dirname)
        SDL2_LIB_PATH=$($FD_CMD --type d 'lib.*SDL2' /usr/lib 2>/dev/null | head -1)

# pacman (Arch)
    elif [[ $is_pacman -eq 0 ]]; then
        SDL2_HEADER_PATH=$($FD_CMD /usr/include 2>/dev/null | head -1 | xargs dirname)
        SDL2_LIB_PATH=$($FD_CMD --type d 'lib.*SDL2' /usr/lib 2>/dev/null | head -1)
fi

}
#makefile rules for compiling our code incase the traditional way dont work
create_makefile() {
    cat <<EOL > Makefile
# Variables
CC = gcc
SRCS = wall.c formulas.c robot.c main.c
OUT = main

# Flags
ifeq (\$(shell uname -s), Darwin)
    # macos specific flags
    CFLAGS = -I${SDL2_HEADER_PATH}
    LDFLAGS = -lSDL2
else
    # linus sponsered specific flags
    CFLAGS = -I${SDL2_HEADER_PATH} \$$(sdl2-config --cflags)
    LDFLAGS = -L${SDL2_LIB_PATH} \$$(sdl2-config --libs) -lm
endif

# Rules for building the main target
all: \$(OUT)

\$(OUT): \$(SRCS)
	\$(CC) \$(SRCS) -o \$(OUT) \$(CFLAGS) \$(LDFLAGS)

clean:
	rm -f \$(OUT)
EOL
}

#Here you attempt to compile the project. First the normal way
#In case it cant find sdl2 but it knows its there then it uses makefile
if [[ $(eval "$compile_cmd" 2>compile_errors.log) ]]; then   
    echo "There were errors during compilation. Trying to makefile"
    if [[ $(grep -c "fatal error: SDL2/SDL.h: No such file or directory" compile_errors.log) -ge 1 ]]; then
        echo "Error: Missing SDL2 headers."
        echo ""
        echo "Gonna try one more time using makefiles to see if it works this way"
        makefile_attempt
        

    elif [[ $(grep -c "fatal error: SDL2_gfxPrimitives.h: No such file or directory" compile_errors.log) -ge 1 ]]; then
        echo "Error: Missing SDL2_gfx headers."
        echo ""
        echo "Gonna try one more time using makefiles to see if it works this way"
        makefile_attempt
    
    else
        echo "Please check the error.log and compile_errors.log for more details."
        makefile_attempt
    fi
else
    echo "Successfully compiled! Everything should be set up correctly."
fi
#This function will make the file and will execute it. Hopefully producing the main binary
makefile_attempt(){

        locate_dependencies
        create_makefile
        make >make_compile.log 2>&1 #just redirecting to a log file to see make stats
        if [[ $? -eq 0 ]]; then
            echo "Compilation successful using Makefile! Thank god"
        else
            echo "Compilation failed using both methods. God damn smth wrong. Ask help from your tutors."
    fi
}


