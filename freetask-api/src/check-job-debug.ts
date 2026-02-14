import { PrismaClient } from '@prisma/client';

async function run() {
  const prisma = new PrismaClient();
  try {
    const jobs = await prisma.job.findMany({
      where: { serviceId: 5 },
      orderBy: { id: 'desc' },
    });

    console.log('--- JOBS SUMMARY ---');
    jobs.forEach((j) => {
      console.log(
        `[${j.id}] ${j.status} (Created: ${j.createdAt.toISOString()})`,
      );
    });
  } catch (e) {
    console.error(e);
  } finally {
    await prisma.$disconnect();
  }
}
run();
