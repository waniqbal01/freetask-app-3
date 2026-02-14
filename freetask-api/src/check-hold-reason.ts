import { PrismaClient } from '@prisma/client';

async function run() {
  const prisma = new PrismaClient();
  try {
    const job = await prisma.job.findUnique({
      where: { id: 9 },
      select: {
        id: true,
        status: true,
        payoutHoldReason: true,
        startedAt: true,
        updatedAt: true,
      },
    });
    console.log(job);
  } catch (e) {
    console.error(e);
  } finally {
    await prisma.$disconnect();
  }
}
run();
