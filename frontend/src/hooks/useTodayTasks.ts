// hooks/useTodayTasks.ts
// React Query hook for fetching and updating tasks
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase, Task } from '../lib/supabase'

export function useTodayTasks() {
  const queryClient = useQueryClient()

  // Fetch tasks due today
  const { data: tasks, isLoading, error } = useQuery<Task[]>({
    queryKey: ['tasks', 'today'],
    queryFn: async () => {
      const today = new Date()
      const startOfDay = new Date(today.setHours(0, 0, 0, 0)).toISOString()
      const endOfDay = new Date(today.setHours(23, 59, 59, 999)).toISOString()

      const { data, error } = await supabase
        .from('tasks')
        .select('*')
        .gte('due_at', startOfDay)
        .lte('due_at', endOfDay)
        .neq('status', 'completed')
        .order('due_at', { ascending: true })

      if (error) throw error
      return data as Task[]
    },
    refetchInterval: 30000, // Auto-refresh every 30 seconds
  })

  // Mark task as complete mutation
  const markCompleteMutation = useMutation({
    mutationFn: async (taskId: string) => {
      const { error } = await supabase
        .from('tasks')
        .update({ 
          status: 'completed',
          updated_at: new Date().toISOString()
        })
        .eq('id', taskId)

      if (error) throw error
    },
    onMutate: async (taskId) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['tasks', 'today'] })

      // Snapshot previous value
      const previousTasks = queryClient.getQueryData<Task[]>(['tasks', 'today'])

      // Optimistic update - remove task from UI immediately
      queryClient.setQueryData<Task[]>(['tasks', 'today'], (old) =>
        old?.filter((task) => task.id !== taskId)
      )

      return { previousTasks }
    },
    onError: (err, taskId, context) => {
      // Rollback on error
      queryClient.setQueryData(['tasks', 'today'], context?.previousTasks)
    },
    onSettled: () => {
      // Refetch to ensure sync
      queryClient.invalidateQueries({ queryKey: ['tasks', 'today'] })
    },
  })

  return {
    tasks: tasks || [],
    isLoading,
    error,
    markComplete: markCompleteMutation.mutate,
    isMarkingComplete: markCompleteMutation.isPending,
  }
}
