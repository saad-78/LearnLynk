// components/TaskTable.tsx
// Clean table component with proper styling
import { Task } from '../lib/supabase'
import { formatDistanceToNow } from 'date-fns'

interface TaskTableProps {
  tasks: Task[]
  onMarkComplete: (taskId: string) => void
  isMarkingComplete: boolean
}

export default function TaskTable({ tasks, onMarkComplete, isMarkingComplete }: TaskTableProps) {
  const getTypeColor = (type: Task['type']) => {
    const colors = {
      call: 'bg-blue-100 text-blue-800 border-blue-200',
      email: 'bg-green-100 text-green-800 border-green-200',
      review: 'bg-purple-100 text-purple-800 border-purple-200',
    }
    return colors[type]
  }

  const formatDueDate = (dueAt: string) => {
    const date = new Date(dueAt)
    return {
      time: date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }),
      relative: formatDistanceToNow(date, { addSuffix: true }),
    }
  }

  if (tasks.length === 0) {
    return (
      <div className="text-center py-12 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
        <svg
          className="mx-auto h-12 w-12 text-gray-400"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
        <h3 className="mt-4 text-lg font-medium text-gray-900">No tasks due today</h3>
        <p className="mt-2 text-sm text-gray-500">You're all caught up! 🎉</p>
      </div>
    )
  }

  return (
    <div className="overflow-hidden shadow ring-1 ring-black ring-opacity-5 rounded-lg">
      <table className="min-w-full divide-y divide-gray-300 bg-white">
        <thead className="bg-gray-50">
          <tr>
            <th className="py-3.5 pl-6 pr-3 text-left text-sm font-semibold text-gray-900">
              Task
            </th>
            <th className="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
              Type
            </th>
            <th className="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
              Application
            </th>
            <th className="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
              Due Time
            </th>
            <th className="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
              Status
            </th>
            <th className="relative py-3.5 pl-3 pr-6">
              <span className="sr-only">Actions</span>
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-200 bg-white">
          {tasks.map((task) => {
            const { time, relative } = formatDueDate(task.due_at)
            return (
              <tr key={task.id} className="hover:bg-gray-50 transition-colors">
                <td className="py-4 pl-6 pr-3">
                  <div className="flex flex-col">
                    <div className="font-medium text-gray-900">{task.title}</div>
                    {task.description && (
                      <div className="text-sm text-gray-500 mt-1">{task.description}</div>
                    )}
                  </div>
                </td>
                <td className="px-3 py-4">
                  <span
                    className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border ${getTypeColor(
                      task.type
                    )}`}
                  >
                    {task.type}
                  </span>
                </td>
                <td className="px-3 py-4 text-sm text-gray-500">
                  <code className="bg-gray-100 px-2 py-1 rounded text-xs font-mono">
                    {task.application_id.slice(0, 8)}...
                  </code>
                </td>
                <td className="px-3 py-4">
                  <div className="flex flex-col">
                    <span className="text-sm font-medium text-gray-900">{time}</span>
                    <span className="text-xs text-gray-500">{relative}</span>
                  </div>
                </td>
                <td className="px-3 py-4">
                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800 border border-yellow-200">
                    {task.status}
                  </span>
                </td>
                <td className="py-4 pl-3 pr-6 text-right">
                  <button
                    onClick={() => onMarkComplete(task.id)}
                    disabled={isMarkingComplete}
                    className="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                  >
                    {isMarkingComplete ? (
                      <svg
                        className="animate-spin h-4 w-4 text-white"
                        xmlns="http://www.w3.org/2000/svg"
                        fill="none"
                        viewBox="0 0 24 24"
                      >
                        <circle
                          className="opacity-25"
                          cx="12"
                          cy="12"
                          r="10"
                          stroke="currentColor"
                          strokeWidth="4"
                        />
                        <path
                          className="opacity-75"
                          fill="currentColor"
                          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                        />
                      </svg>
                    ) : (
                      <>
                        <svg
                          className="mr-1.5 h-4 w-4"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M5 13l4 4L19 7"
                          />
                        </svg>
                        Complete
                      </>
                    )}
                  </button>
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
