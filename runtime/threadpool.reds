Red/System [
	Title:	"Thread Pool"
	Author: "Xie Qingtian"
	File: 	%threadpool.reds
	Tabs:	4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#include %queue.reds
#include %threads.reds

threadpool: context [

#either OS = 'Windows [

	#enum task-status! [
		TASK_WAITING
		TASK_RUNNING
		TASK_DONE
	]

	SYSTEM_INFO!: alias struct! [
		dwOemId						[integer!]
		dwPageSize					[integer!]
		lpMinimumApplicationAddress [byte-ptr!]
		lpMaximumApplicationAddress [byte-ptr!]
		dwActiveProcessorMask		[int-ptr!]
		dwNumberOfProcessors		[integer!]
		dwProcessorType				[integer!]
		dwAllocationGranularity		[integer!]
		wProcessorLevel				[integer!]
		;wProcessorRevision
	]

	processor-count: func [
		return: [integer!]
		/local
			info [SYSTEM_INFO! value]
			n	 [integer!]
	][
		set-memory as byte-ptr! :info null-byte size? SYSTEM_INFO!
		GetNativeSystemInfo :info
		n: info/dwNumberOfProcessors		;-- maximum number of threads
		either zero? n [1][n]
	]
][
	processor-count: func [
		return: [integer!]
		/local
			n	 [integer!]
	][
		n: platform/sysconf _SC_NPROCESSORS_ONLN
		if zero? n [n: platform/sysconf _SC_NPROCESSORS_CONF]
		if zero? n [n: 1]
		n
	]
]

	task!: alias struct! [
		handler		[int-ptr!]	;-- thread-func!
		data		[int-ptr!]	;-- user data
	]

	worker!: alias struct! [
		running?	[logic!]
		idle-tm		[integer!]	;-- if a worker idle too long, exit it
		handle		[handle!]	;-- thread handle
	]

	worker0!: alias struct! [
		running?	[logic!]
		event		[handle!]
		handle		[handle!]
	]

	tasks: as queue! 0
	workers: as worker! 0
	worker0: declare worker0!
	n-worker: 0
	n-task: 0
	n-max: 0

	zero-memory: func [
		dest	[byte-ptr!]
		size	[integer!]
	][
		loop size [dest/value: #"^@" dest: dest + 1]
	]

	worker0-func: func [		;-- worker 0 never exit
		#if OS <> 'Windows [[cdecl]]
		self	[worker0!]
		/local
			task	[task!]
			handler	[thread-func!]
			r		[integer!]
	][
		while [self/running?][
			#either OS = 'Windows [
				r: thread/WaitForSingleObject self/event -1
				assert r <> -1
			][
				platform/wait 0.001
			]
			task: as task! queue/pop tasks
			;assert task <> null
			if task <> null [
				handler: as thread-func! task/handler
				handler task/data
				system/atomic/sub :n-task 1
				free as byte-ptr! task
			]
		]
	]

	worker-func: func [
		#if OS <> 'Windows [[cdecl]]
		self	[worker!]
		/local
			task	[task!]
			handler	[thread-func!]
			cnt		[integer!]
	][
		while [self/running?][
			task: as task! queue/pop tasks
			either task <> null [
				self/idle-tm: 0
				handler: as thread-func! task/handler
				handler task/data
				free as byte-ptr! task
				system/atomic/sub :n-task 1
			][
				cnt: self/idle-tm + 1
				either cnt = 500 [
					self/running?: no
					system/atomic/sub :n-worker 1
					cnt: 0
				][
					platform/wait 0.001
				]
				self/idle-tm: cnt
			]
		]
	]
	
	init: func [][
		tasks: queue/create 2000
		n-max: -1 + processor-count
		workers: as worker! allocate n-max * size? worker!
		zero-memory as byte-ptr! workers n-max * size? worker!
		worker0/running?: no
	]

	init-workers: does [
		loop n-max [add-worker]
	]

	add-worker: func [/local w [worker!]][
		w: workers
		loop n-max [		;-- find a free worker
			either w/running? [w: w + 1][break]
		]
		if workers + n-max <> w [
			system/atomic/add :n-worker 1
			if w/handle <> null [
				thread/detach w/handle
				w/handle: null
			]
			w/running?: yes
			w/idle-tm: 0
			w/handle: thread/start as int-ptr! :worker-func as int-ptr! w 0
		]
	]

	add-task: func [
		handler [int-ptr!]
		data	[int-ptr!]
		return: [logic!]
		/local
			task	[task!]
			res		[logic!]
			sz		[integer!]
	][
		system/atomic/add :n-task 1
		task: as task! allocate size? task!
		task/handler: handler
		task/data: data
		res: queue/push tasks as int-ptr! task
		assert n-worker > 0
		res
	]

	wait: func [][
		until [
			platform/wait 0.001
			zero? n-task
		]
	]

	destroy: func [			;-- destroy the thread pool even there are tasks left
		/local w [worker!]
	][
		if worker0/running? [
			worker0/running?: no
			thread/kill worker0/handle
			thread/detach worker0/handle
		]
		loop n-max [
			w: workers
			if w/running? [
				w/running?: no
				thread/kill w/handle
			]
			if w/handle <> null [thread/detach w/handle]
			w: w + 1
		]
		queue/destroy tasks
		free as byte-ptr! workers
	]
]

comment {
func1: func [data [int-ptr!]][
	probe "1"
	OS-Sleep 20000
	probe "11"
]

func2: func [data [int-ptr!]][
	probe "2"
	OS-Sleep 20000
	probe "22"
]

func3: func [data [int-ptr!]][
	probe "3"
	OS-Sleep 20000
	probe "33"
]

funcN: func [data [int-ptr!]][
	OS-Sleep 1000
]

test: func [
	/local
		n	[integer!]
		p	[int-ptr!]
][
	threadpool/init
	threadpool/add-task as int-ptr! :func1 null
	threadpool/add-task as int-ptr! :func2 null
	threadpool/add-task as int-ptr! :func3 null
	n: 3
	loop 100 [
		n: n + 1
		p: as int-ptr! allocate size? int-ptr!
		p/value: n
		threadpool/add-task as int-ptr! :funcN p
	]
	probe "waiting..."
	threadpool/wait
	probe "done"
]

test
}