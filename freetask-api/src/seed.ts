import { PrismaClient, UserRole, JobStatus, Prisma } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  await prisma.notification.deleteMany();
  await prisma.review.deleteMany();
  await prisma.chatMessage.deleteMany();
  await prisma.job.deleteMany();
  await prisma.service.deleteMany();
  await prisma.user.deleteMany();

  const password = await bcrypt.hash('password123', 10);

  const client = await prisma.user.create({
    data: {
      email: 'client.demo@example.com',
      name: 'Client Demo',
      password,
      role: UserRole.CLIENT,
    },
  });

  const freelancer = await prisma.user.create({
    data: {
      email: 'freelancer.demo@example.com',
      name: 'Freelancer Demo',
      password,
      role: UserRole.FREELANCER,
    },
  });

  const services = await Promise.all([
    prisma.service.create({
      data: {
        title: 'Logo Design',
        description: 'Reka logo moden untuk jenama baharu.',
        price: new Prisma.Decimal(250),
        category: 'Design',
        freelancerId: freelancer.id,
      },
    }),
    prisma.service.create({
      data: {
        title: 'Landing Page',
        description: 'Bina laman pendaratan yang pantas dan responsif.',
        price: new Prisma.Decimal(800),
        category: 'Development',
        freelancerId: freelancer.id,
      },
    }),
    prisma.service.create({
      data: {
        title: 'Social Media Kit',
        description: 'Templat grafik untuk kempen media sosial.',
        price: new Prisma.Decimal(350),
        category: 'Marketing',
        freelancerId: freelancer.id,
      },
    }),
  ]);

  const inProgressJob = await prisma.job.create({
    data: {
      title: 'Logo untuk aplikasi fintech',
      description: 'Perlu identiti visual ringkas dan moden.',
      status: JobStatus.IN_PROGRESS,
      amount: new Prisma.Decimal(600),
      serviceId: services[0].id,
      clientId: client.id,
      freelancerId: freelancer.id,
    },
  });

  const completedJob = await prisma.job.create({
    data: {
      title: 'Kempen media sosial Q2',
      description: 'Sediakan 10 visual dan kapsyen untuk promosi.',
      status: JobStatus.COMPLETED,
      amount: new Prisma.Decimal(500),
      serviceId: services[2].id,
      clientId: client.id,
      freelancerId: freelancer.id,
    },
  });

  await prisma.chatMessage.createMany({
    data: [
      {
        content: 'Hai, saya telah semak keperluan logo.',
        jobId: inProgressJob.id,
        senderId: freelancer.id,
      },
      {
        content: 'Baik, warna utama biru dan hijau ya.',
        jobId: inProgressJob.id,
        senderId: client.id,
      },
      {
        content: 'Saya akan hantar konsep pertama petang ini.',
        jobId: inProgressJob.id,
        senderId: freelancer.id,
      },
    ],
  });

  await prisma.notification.createMany({
    data: [
      {
        userId: freelancer.id,
        type: 'JOB_CREATED',
        title: 'Job baharu ditempah',
        body: `${client.name} menempah ${services[0].title}.`,
        metadata: { jobId: inProgressJob.id, serviceId: services[0].id },
      },
      {
        userId: client.id,
        type: 'JOB_UPDATED',
        title: 'Status job dikemas kini',
        body: `${services[2].title} telah diselesaikan.`,
        metadata: { jobId: completedJob.id, status: completedJob.status },
      },
    ],
  });

  console.log('Seed data created successfully');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
