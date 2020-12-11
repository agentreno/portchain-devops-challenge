


let previousCpuUsage:NodeJS.CpuUsage = process.cpuUsage();
let previousTime = process.hrtime();

export const stats = () => {
  const memoryUsage = process.memoryUsage();
  const hrtime = process.hrtime(previousTime)
  previousTime = process.hrtime()

  const cpuUsage = process.cpuUsage(previousCpuUsage)
  previousCpuUsage = process.cpuUsage()
  
  const elapsedTime = hrtime[0]*1000*1000 + hrtime[1]/1000

  return {
    memory: memoryUsage.rss,
    uptime: process.uptime(),
    cpuRatio: (cpuUsage.user + cpuUsage.system) / elapsedTime
  }
}