#! /usr/bin/env python3.0
"""
editor.py - OGRE Script Editor.

Description:
  The is an interactive tool for building test script snippets. 

Usage:
  editor.py [<signal_file> ...]

"""
import copy
import imp
import os.path
import sys
import tkinter
import tkinter.font
from   tkinter.filedialog import askopenfilename
from   tkinter.filedialog import asksaveasfilename

import ogre


BG_COLOR     = "lightsteelblue"
FIELD_COLOR  = "lightblue"
FRAME_COLOR  = "lightsteelblue"
BUTTON_COLOR = "lightblue"
HEADER_COLOR = "steelblue"

STICKY_ALL = tkinter.N + tkinter.S + tkinter.W + tkinter.E

# ----------------------------------------------------------------
class Int:
    """
    Represents an integer in a signal.
    """
    def __init__(self, parent, name, obj, i):
        self.name = name
        self.obj = obj

        self.value_entry = tkinter.Entry(parent, bg=FIELD_COLOR)
        self.value_entry.insert(0, obj)
        self.value_entry.grid(row=i, column=1, sticky=tkinter.W)

    def value(self):
        val = int(self.value_entry.get())
        self.obj = val
        return val

    def as_string(self, prefix):
        val = int(self.value_entry.get())
        if val != self.obj:
            return "%s = %d\n" % (prefix, self.value())
        return ""
    
    def as_verify_string(self, prefix):
        return "assert(%s == %d)\n" % (prefix, self.value())


# ----------------------------------------------------------------
class Array:
    """
    Represents an array in a signal.
    """
    def __init__(self, parent, name, array, i):
        self.name = name
        self.array = array
        self.tree = []

        frame = tkinter.Frame(parent, relief=tkinter.GROOVE, bd=2, bg=FRAME_COLOR)
        frame.grid(row=i, column=1, sticky=tkinter.W)

        length = len(array)
        for k in range(length):
            attr_name = "[%d]" % k
            attr = array[k]

            value_label = tkinter.Label(frame, bg=FRAME_COLOR,
                                        text="%d:" % k)
            value_label.grid(row=k, column=0, sticky=tkinter.E)
            if isinstance(attr, ogre.Struct):
                item = Struct(frame, attr_name, attr, k)
            else:
                item = Int(frame, attr_name, attr, k)
            self.tree.append(item)

    def value(self):
        for k, item in enumerate(self.tree):
            self.array[k] = item.value()
        return self.array

    def as_string(self, prefix):
        s = ""
        for item in self.tree:
            s = s + item.as_string(prefix + item.name)
        return s

    def as_verify_string(self, prefix):
        s = ""
        for item in self.tree:
            s = s + item.as_verify_string(prefix + item.name)
        return s

# ----------------------------------------------------------------
class Struct:
    """
    Represents a struct in a signal.
    """
    def __init__(self, parent, name, struct, i):
        self.name = name
        self.struct = struct
        self.tree = []

        frame = tkinter.Frame(parent, relief=tkinter.GROOVE, bd=2, bg=FRAME_COLOR)
        frame.grid(row=i, column=1, sticky=tkinter.W)

        j = 0
        for attr_name in struct.attributes():
            if attr_name == "sigNo":
                continue
            attr = getattr(struct, attr_name)

            value_label = tkinter.Label(frame, text=attr_name + ":", bg=FRAME_COLOR)
            value_label.grid(row=j, column=0, sticky=tkinter.E)

            if isinstance(attr, ogre.Struct):
                item = Struct(frame, attr_name, attr, j)
            elif isinstance(attr, ogre.Array):
                item = Array(frame, attr_name, attr, j)
            elif isinstance(attr, int):
                item = Int(frame, attr_name, attr, j)
            else:
                print('leaf', j)
            self.tree.append(item)
            j = j + 1

    def value(self):
        for item in self.tree:
            setattr(self.struct, item.name, item.value())
        return self.struct

    def as_string(self, prefix):
        s = ""
        for item in self.tree:
            s = s + item.as_string(prefix + "." + item.name)
        return s

    def as_verify_string(self, prefix):
        s = ""
        for item in self.tree:
            s = s + item.as_verify_string(prefix + "." + item.name)
        return s


# ----------------------------------------------------------------
class HeaderFrame(tkinter.Frame):
    """
    Title frame
    """
    def __init__(self, parent, title):
        tkinter.Frame.__init__(self, parent, bg=HEADER_COLOR)
        self.pack(fill=tkinter.X)
        myfont = tkinter.font.Font(family="Helvetica", size=12, weight='bold')
        label = tkinter.Label(self, text=title, bg=HEADER_COLOR,
                              fg="white", font=myfont)
        label.pack(padx=2, pady=2)


# ----------------------------------------------------------------
class SignalListFrame(tkinter.Frame):
    """
    Signal list frame.
    """
    def __init__(self, app, parent):
        tkinter.Frame.__init__(self, parent, bg=BG_COLOR,
                               relief=tkinter.RAISED, bd=2)
        self.app = app

        HeaderFrame(self, "Signals")

        # Content frame
        content = tkinter.Frame(self, bg=FRAME_COLOR, relief=tkinter.SUNKEN, bd=1)
        content.pack(fill=tkinter.BOTH, expand=1)
        content.grid_rowconfigure(0, weight=1)
        content.grid_columnconfigure(0, weight=1)

        # Scroll bar
        sby = tkinter.Scrollbar(content)
        sby.grid(row=0, column=1, sticky=tkinter.N + tkinter.S)

        # List frame
        self.list_frame = tkinter.Listbox(content, 
                                          yscrollcommand=sby.set,
                                          bg=FIELD_COLOR, width=40, bd=0)
        self.list_frame.grid(row=0, column=0, sticky=tkinter.N + tkinter.S + tkinter.W + tkinter.E)
        self.list_frame.bind("<Double-Button-1>", self.do_double_click)
        sby.config(command=self.list_frame.yview)

        # Button frame
        button_frame = tkinter.Frame(self, bg=FRAME_COLOR)
        button_frame.pack(fill=tkinter.X)
        open_button = tkinter.Button(button_frame, text="Open",
                                      bg=BUTTON_COLOR,
                                      command=self.app.do_open)
        open_button.pack(padx=4, pady=4)

    def do_double_click(self, e):
        for index in self.list_frame.curselection():
            self.app.do_open_send_signal(int(index))

    def add(self, sig_name):
        self.list_frame.insert(tkinter.END, sig_name)


# ----------------------------------------------------------------
class ReceiveFrame(tkinter.Frame):
    """
    Received signals frame.
    """
    def __init__(self, app, parent):
        tkinter.Frame.__init__(self, parent, bg=BG_COLOR,
                               relief=tkinter.RAISED, bd=2)
        self.app = app

        HeaderFrame(self, "Receive")

        # Content frame
        content = tkinter.Frame(self, bg=FRAME_COLOR, relief=tkinter.SUNKEN, bd=1)
        content.pack(fill=tkinter.BOTH, expand=1)
        content.grid_rowconfigure(0, weight=1)
        content.grid_columnconfigure(0, weight=1)

        # Scroll bar
        sby = tkinter.Scrollbar(content)
        sby.grid(row=0, column=1, sticky=tkinter.N + tkinter.S)

        # List frame
        self.list_frame = tkinter.Listbox(content,
                                          yscrollcommand=sby.set,
                                          bg=FIELD_COLOR, width=40, bd=0)
        self.list_frame.grid(row=0, column=0, sticky=tkinter.N + tkinter.S + tkinter.W + tkinter.E)
        self.list_frame.bind("<Double-Button-1>", self.do_double_click)
        sby.config(command=self.list_frame.yview)

        # Button frame
        button_frame = tkinter.Frame(self, bg=FRAME_COLOR)
        button_frame.pack(fill=tkinter.X)
        receive_button = tkinter.Button(button_frame, text="Receive",
                                        bg=BUTTON_COLOR,
                                        command=self.app.do_receive)
        receive_button.pack(padx=4, pady=4)

    def do_double_click(self, e):
        for index in self.list_frame.curselection():
            self.app.do_open_rec_signal(int(index))

    def add(self, sig, var):
        signal = "%s:  %s.%s" % (var, sig.__class__.__module__, sig.__class__.__name__)
        self.list_frame.insert(tkinter.END, signal)

# ----------------------------------------------------------------
class LogFrame(tkinter.Frame):
    """
    Script window
    """
    def __init__(self, app, parent):
        tkinter.Frame.__init__(self, parent, bg=BG_COLOR,
                               relief=tkinter.RAISED, bd=2)
        self.app = app

        HeaderFrame(self, "Script")

        # Content frame
        content = tkinter.Frame(self, bg=FRAME_COLOR, relief=tkinter.SUNKEN, bd=1)
        content.pack(fill=tkinter.BOTH, expand=1)
        content.grid_rowconfigure(0, weight=1)
        content.grid_columnconfigure(0, weight=1)

        # Scroll bar
        sby = tkinter.Scrollbar(content)
        sby.grid(row=0, column=1, sticky=tkinter.N + tkinter.S)
        sbx = tkinter.Scrollbar(content, orient=tkinter.HORIZONTAL)
        sbx.grid(row=1, column=0, sticky=tkinter.W + tkinter.E)

        # List frame
        self.log_frame = tkinter.Text(content, wrap=tkinter.NONE,
                                      yscrollcommand=sby.set,
                                      xscrollcommand=sbx.set,
                                      bg=FIELD_COLOR, width=40, bd=0)
        self.log_frame.grid(row=0, column=0, sticky=tkinter.N + tkinter.S + tkinter.W + tkinter.E)
        sby.config(command=self.log_frame.yview)
        sbx.config(command=self.log_frame.xview)

        # Button frame
        button_frame = tkinter.Frame(self, bg=FRAME_COLOR)
        button_frame.pack(fill=tkinter.X)
        save_button = tkinter.Button(button_frame, text="Save",
                                     bg=BUTTON_COLOR,
                                     command=self.app.do_save_script)
        save_button.pack(padx=4, pady=4)

    def get_log(self):
        return self.log_frame.get(1.0, tkinter.END)
    
    def log_string(self, s):
        self.log_frame.insert(tkinter.END, s + "\n")

    def log_connect(self, url, proc):
        s = "\n"
        s += "url = '%s'\n" % url
        s += "proc = ogre.Process(url, '%s')\n" % (proc)
        self.log_frame.insert(tkinter.END, s)

    def log_disconnect(self):
        s = "\n"
        s += "proc.close()\n"
        self.log_frame.insert(tkinter.END, s)

    def log_import(self, mod):
        s = "\n"
        s += "import %s\n" % (mod)
        self.log_frame.insert(tkinter.END, s)

    def log_send(self, sig, tree):
        s = "\n"
        s += "%s = %s.%s()\n" % (tree.name, 
                                 sig.__class__.__module__,
                                 sig.__class__.__name__)
        s += tree.as_string(tree.name)
        s += "proc.send(%s)\n" % tree.name
        self.log_frame.insert(tkinter.END, s)

    def log_receive(self, var):
        s = "\n"
        s += "%s = proc.receive()\n" % (var)
        self.log_frame.insert(tkinter.END, s)

    def log_verify(self, sig, tree):
        s = "\n"
        s += tree.as_verify_string(tree.name)
        self.log_frame.insert(tkinter.END, s)


# ----------------------------------------------------------------
class ConnectionFrame(tkinter.Frame):
    """
    Connection frame.
    """
    def __init__(self, app, parent):
        tkinter.Frame.__init__(self, parent, bg=BG_COLOR,
                               relief=tkinter.RAISED, bd=2)
        self.app = app

        HeaderFrame(self, "Connection")

        # Login frame
        login_frame = tkinter.Frame(self, bg=FRAME_COLOR)
        login_frame.pack(fill=tkinter.BOTH)

        url_label = tkinter.Label(login_frame, bg=FRAME_COLOR, text="URL:")
        url_label.grid(row=0, column=0, sticky=tkinter.E, padx=4, pady=4)

        self.url_entry = tkinter.Entry(login_frame, bg=FIELD_COLOR, width=32)
        self.url_entry.insert(0, "tcp://172.17.226.207:22001")
        self.url_entry.grid(row=0, column=1, sticky=tkinter.W, padx=4, pady=4)

        proc_label = tkinter.Label(login_frame, bg=FRAME_COLOR, text="Process:")
        proc_label.grid(row=1, column=0, sticky=tkinter.E, padx=4, pady=4)

        self.proc_entry = tkinter.Entry(login_frame, bg=FIELD_COLOR)
        self.proc_entry.insert(0, "ogre_echo")
        self.proc_entry.grid(row=1, column=1, sticky=tkinter.W, padx=4, pady=4)

        # Button frame
        button_frame = tkinter.Frame(self, bg=FRAME_COLOR)
        button_frame.pack(fill=tkinter.X)
        connect_button = tkinter.Button(button_frame, text="Connect",
                                        bg=BUTTON_COLOR,
                                        command=self.do_connect)
        connect_button.pack(padx=4, pady=4, side=tkinter.LEFT)
        disconn_button = tkinter.Button(button_frame, text="Disconnect",
                                        bg=BUTTON_COLOR,
                                        command=self.app.do_disconnect)
        disconn_button.pack(padx=4, pady=4, side=tkinter.LEFT)
        quit_button = tkinter.Button(button_frame, text="Quit",
                                     bg=BUTTON_COLOR,
                                     command=self.quit)
        quit_button.pack(padx=4, pady=4, side=tkinter.LEFT)

    def do_connect(self):
        url = self.url_entry.get()
        proc = self.proc_entry.get()
        self.app.do_connect(url, proc)


# ----------------------------------------------------------------
class SignalFrame(tkinter.Frame):
    """
    Signal frame.
    """
    def __init__(self, app, parent, sig, var, rx=False):
        tkinter.Frame.__init__(self, parent, bg=BG_COLOR,
                               relief=tkinter.RAISED, bd=2)
        self.app = app
        self.sig = sig
        self.parent = parent
        parent.protocol("WM_DELETE_WINDOW", self.do_close)

        HeaderFrame(self, sig.__class__.__name__)

        # Sig frame
        sig_frame = tkinter.Frame(self, bg=FRAME_COLOR)
        sig_frame.pack(fill=tkinter.BOTH, expand=1)
        self.tree = Struct(sig_frame, var, sig, 0)

        # Button frame
        button_frame = tkinter.Frame(self, bg=FRAME_COLOR)
        button_frame.pack(fill=tkinter.X)

        if rx:
            verify_button = tkinter.Button(button_frame, text="Verify",
                                           bg=BUTTON_COLOR,
                                           command=self.do_verify)
            verify_button.pack(side=tkinter.LEFT, padx=4, pady=4)
        else:
            send_button = tkinter.Button(button_frame, text="Send",
                                         bg=BUTTON_COLOR,
                                         command=self.do_send)
            send_button.pack(side=tkinter.LEFT, padx=4, pady=4)
        close_button = tkinter.Button(button_frame, text="Close",
                                      bg=BUTTON_COLOR,
                                      command=self.do_close)
        close_button.pack(side=tkinter.LEFT, padx=4, pady=4)

    def do_close(self):
        self.app.close_signal_window(self.parent)
        
    def do_send(self):
        self.app.do_send(self.sig, self.tree)

    def do_verify(self):
        self.app.do_verify(self.sig, self.tree)


# ----------------------------------------------------------------
class StatusBarFrame(tkinter.Frame):

    def __init__(self, parent):
        tkinter.Frame.__init__(self, parent, bg=BG_COLOR)
        self.label = tkinter.Label(self, bd=1, relief=tkinter.SUNKEN,
                                   anchor=tkinter.W)
        self.label.pack(fill=tkinter.X)

    def error(self, txt):
        self.label['bg'] = "red"
        self.label.config(text=txt)
        self.label.update_idletasks()

    def info(self, txt=None):
        self.label['bg'] = "lightgreen"
        if txt is None:
            txt = ""
        self.label.config(text=txt)
        self.label.update_idletasks()


# ----------------------------------------------------------------
class App:
    """Application.

    """
    unique_sig = 0

    def __init__(self, root):
        self.root = root
        self.gw = None
        self.pid = 0
        self.sig_list = []
        self.receive_list = []

        # Top level structure frames
        top_frame = tkinter.Frame(root, bg=BG_COLOR)
        top_frame.pack(side=tkinter.TOP, fill=tkinter.BOTH, expand=1)
        top_frame.grid_rowconfigure(0, weight=1)
        top_frame.grid_rowconfigure(1, weight=1)
        top_frame.grid_rowconfigure(2, weight=0)
        top_frame.grid_columnconfigure(0, weight=1)
        top_frame.grid_columnconfigure(1, weight=1)

        # Application frames
        self.sig_frame = SignalListFrame(self, top_frame)
        self.log_frame = LogFrame(self, top_frame)
        self.rec_frame = ReceiveFrame(self, top_frame)
        self.con_frame = ConnectionFrame(self, top_frame)
        self.status = StatusBarFrame(top_frame)

        # Layout
        self.sig_frame.grid(row=0, column=0, sticky=STICKY_ALL)
        self.log_frame.grid(row=1, column=0, sticky=STICKY_ALL)
        self.rec_frame.grid(row=0, column=1, sticky=STICKY_ALL)
        self.con_frame.grid(row=1, column=1, sticky=tkinter.S + tkinter.W + tkinter.E)
        self.status.grid(row=2, column=0, columnspan=2,
                         sticky=tkinter.S + tkinter.W + tkinter.E)

        # Other inits
        #self.status.info("Disconnected")
        self.log_frame.log_string("import ogre")


    def load_signal_file(self, path):
        """Load signals from a python signal definition file.

        Instantaite each signal and insert the signal in the sig_list
        list. 
        """
        self.status.info()
        try:
            file_name = os.path.basename(path)
            module_name, ext = os.path.splitext(file_name)
            with open(path) as sig_file:
                module = imp.load_source(module_name, path, sig_file)
        except Exception:
            self.status.error("Error reading '%s' signal file" % file_name)
            return

        for attr, obj in module.__dict__.items():
            if isinstance(obj, type) and issubclass(obj, ogre.Signal):
                sig = obj()
                self.sig_list.append((attr, sig))
                self.sig_frame.add("%s.%s" % (module_name, attr))

        self.log_frame.log_import(module_name)

    def close_signal_window(self, closed_window):
        """SignalFrame window closing.

        Called when a SignalFRame window is about to be close. Destory
        the window and remove the windows reference in the recive_list
        (if any).
        """
        for i, asig in enumerate(self.receive_list):
            (sig, var, window) = asig
            if window is closed_window:
                self.receive_list[i] = (sig, var, None)
        closed_window.destroy()

        
    # Command handlers

    def do_open(self):
        self.status.info()
        file_name = askopenfilename(filetypes=[("signal descriptor", ".py")],
                                    title="Open Signal File",
                                    parent= self.root)
        if file_name:
            module = self.load_signal_file(file_name)

    def do_open_send_signal(self, index):
        self.status.info()
        name, sig = self.sig_list[index]

        self.unique_sig += 1
        var = "sig%d" % self.unique_sig

        window = tkinter.Toplevel()
        window.title(var)
        sig_frame = SignalFrame(self, window, copy.deepcopy(sig), var)
        sig_frame.pack(fill=tkinter.BOTH, expand=1)

    def do_open_rec_signal(self, index):
        self.status.info()
        sig, var, window = self.receive_list[index]

        if window:
            window.lift()
        else:
            window = tkinter.Toplevel()
            window.title(var)
            sig_frame = SignalFrame(self, window, sig, var, rx=True)
            sig_frame.pack(fill=tkinter.BOTH, expand=1)
            self.receive_list[index] = (sig, var, window)

    def do_connect(self, url, proc):
        if self.gw:
            self.status.error("Already connected")
            return

        try:
            self.gw = ogre.create(url, "siged")
            self.gw.hunt(proc)
            sig = self.gw.receive(timeout=1.0)
            if sig is None:
                self.gw.close()
                self.gw = None
                self.status.error("Can't find %s" % proc)
                return
            self.pid = sig.sender()
            self.log_frame.log_connect(url, proc)
            self.status.info("Connected to %s" % proc)
        except Exception as e:
            self.status.error("Connect error: %s" % e)


    def do_disconnect(self):
        try:
            if self.gw:
                self.gw.close()
                self.log_frame.log_disconnect()
                self.status.info("Disconnected")
        except Exception as e:
            self.status.error("Disconnect error %s" % e)
        self.gw = None


    def do_send(self, old_sig, tree):
        if not self.gw:
            self.status.error("Not connected")
            return

        try:
            self.log_frame.log_send(old_sig, tree)
            sig = tree.value()
            self.gw.send(sig, self.pid)
            self.status.info("Sent %s" % sig.__class__.__name__)
        except Exception as e:
            self.status.error("Send error %s" % e)


    def do_verify(self, sig, tree):
        self.status.info()
        self.log_frame.log_verify(sig, tree)


    def do_receive(self):
        if not self.gw:
            self.status.error("Not connected")
            return

        self.status.info("")
        try:
            while True:
                sig = self.gw.receive(timeout=0.1)
                if sig is None:
                    return

                self.unique_sig += 1
                var = "sig%d" % self.unique_sig

                self.receive_list.append((sig, var, None))
                self.rec_frame.add(sig, var)
                self.log_frame.log_receive(var)
        except Exception as e:
            self.status.error("Receive error %s" % e)


    def do_save_script(self):
        self.status.info()
        file_name = asksaveasfilename(filetypes=[("python script", ".py")],
                                      title="Save Script",
                                      parent= self.root)
        if file_name:
            with open(file_name, "w") as log_file:
                log_file.write(self.log_frame.get_log())
            

# ----------------------------------------------------------------
def main(args):
    """Main entry point.

    Create the main window and start the main loop.

    Parameters:
        args  -- list of signal description files to 
    """
    root = tkinter.Tk()
    root.title("OGRE Editor")
    app = App(root)
    for path in args:
        app.load_signal_file(path)
    root.mainloop()


# ----------------------------------------------------------------      
if __name__ == '__main__':
    main(sys.argv[1:])


# End of file
