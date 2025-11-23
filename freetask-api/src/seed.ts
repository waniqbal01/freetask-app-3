import { PrismaClient, UserRole, JobStatus, Prisma } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  await prisma.review.deleteMany();
  await prisma.chatMessage.deleteMany();
  await prisma.job.deleteMany();
  await prisma.service.deleteMany();
  await prisma.user.deleteMany();

  const rawPassword = 'Password123!';
  const password = await bcrypt.hash(rawPassword, 10);

  const freelancers = await Promise.all([
    prisma.user.create({
      data: {
        email: 'freelancer1@example.com',
        name: 'Freelancer One',
        password,
        role: UserRole.FREELANCER,
      },
    }),
    prisma.user.create({
      data: {
        email: 'freelancer2@example.com',
        name: 'Freelancer Two',
        password,
        role: UserRole.FREELANCER,
      },
    }),
  ]);

  const clients = await Promise.all([
    prisma.user.create({
      data: {
        email: 'client1@example.com',
        name: 'Client One',
        password,
        role: UserRole.CLIENT,
      },
    }),
    prisma.user.create({
      data: {
        email: 'client2@example.com',
        name: 'Client Two',
        password,
        role: UserRole.CLIENT,
      },
    }),
  ]);

  const admin = await prisma.user.create({
    data: {
      email: 'admin@example.com',
      name: 'Admin User',
      password,
      role: UserRole.ADMIN,
    },
  });

  const services = await Promise.all([
    prisma.service.create({
      data: {
        title: 'Logo Design',
        description: 'Professional logo design service.',
        price: new Prisma.Decimal(150),
        category: 'Design',
        freelancerId: freelancers[0].id,
      },
    }),
    prisma.service.create({
      data: {
        title: 'Website Development',
        description: 'Full-stack website development.',
        price: new Prisma.Decimal(1200),
        category: 'Development',
        freelancerId: freelancers[0].id,
      },
    }),
    prisma.service.create({
      data: {
        title: 'SEO Optimization',
        description: 'Improve your search engine rankings.',
        price: new Prisma.Decimal(400),
        category: 'Marketing',
        freelancerId: freelancers[1].id,
      },
    }),
    prisma.service.create({
      data: {
        title: 'Social Media Management',
        description: 'Grow and manage your social media presence.',
        price: new Prisma.Decimal(300),
        category: 'Marketing',
        freelancerId: freelancers[1].id,
      },
    }),
  ]);

  const jobs = await Promise.all([
    prisma.job.create({
      data: {
        title: 'Logo Design for Startup',
        description: 'Need a modern logo for a tech startup.',
        status: JobStatus.PENDING,
        amount: new Prisma.Decimal(200),
        serviceId: services[0].id,
        clientId: clients[0].id,
        freelancerId: freelancers[0].id,
      },
    }),
    prisma.job.create({
      data: {
        title: 'Landing Page Build',
        description: 'Simple responsive landing page.',
        status: JobStatus.ACCEPTED,
        amount: new Prisma.Decimal(750),
        serviceId: services[1].id,
        clientId: clients[1].id,
        freelancerId: freelancers[0].id,
      },
    }),
    prisma.job.create({
      data: {
        title: 'SEO for E-commerce',
        description: 'Optimize SEO for online shop.',
        status: JobStatus.IN_PROGRESS,
        amount: new Prisma.Decimal(600),
        serviceId: services[2].id,
        clientId: clients[1].id,
        freelancerId: freelancers[1].id,
      },
    }),
    prisma.job.create({
      data: {
        title: 'Social Campaign',
        description: 'Two-week campaign management.',
        status: JobStatus.CANCELLED,
        amount: new Prisma.Decimal(280),
        serviceId: services[3].id,
        clientId: clients[0].id,
        freelancerId: freelancers[1].id,
      },
    }),
    prisma.job.create({
      data: {
        title: 'Storefront redesign',
        description: 'Completed storefront redesign.',
        status: JobStatus.COMPLETED,
        amount: new Prisma.Decimal(1200),
        serviceId: services[1].id,
        clientId: clients[0].id,
        freelancerId: freelancers[0].id,
      },
    }),
    prisma.job.create({
      data: {
        title: 'Logo tweaks round',
        description: 'Rejected after initial consultation.',
        status: JobStatus.REJECTED,
        amount: new Prisma.Decimal(150),
        serviceId: services[0].id,
        clientId: clients[1].id,
        freelancerId: freelancers[1].id,
      },
    }),
    prisma.job.create({
      data: {
        title: 'E-commerce audit',
        description: 'Client disputed deliverables.',
        status: JobStatus.DISPUTED,
        amount: new Prisma.Decimal(450),
        disputeReason: 'Report missing agreed benchmarks.',
        serviceId: services[2].id,
        clientId: clients[0].id,
        freelancerId: freelancers[1].id,
      },
    }),
  ]);

  await prisma.review.create({
    data: {
      jobId: jobs[4].id,
      rating: 5,
      comment: 'Great work delivered on time!',
      reviewerId: clients[0].id,
      revieweeId: freelancers[0].id,
    },
  });

  await prisma.chatMessage.createMany({
    data: [
      {
        jobId: jobs[2].id,
        senderId: clients[1].id,
        content: 'Can you share progress screenshots?',
      },
      {
        jobId: jobs[2].id,
        senderId: freelancers[1].id,
        content: 'Sure, uploading them later today.',
      },
    ],
  });

  console.log('Seed data created successfully');
  console.log('Demo users (email / role):');
  [admin, ...clients, ...freelancers].forEach((user) => {
    console.log(`- ${user.email} / ${user.role}`);
  });
  console.log(`Demo password for all users: ${rawPassword}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
