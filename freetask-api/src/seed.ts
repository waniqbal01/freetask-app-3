import { PrismaClient, UserRole, JobStatus, Prisma } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  await prisma.review.deleteMany();
  await prisma.chatMessage.deleteMany();
  await prisma.job.deleteMany();
  await prisma.service.deleteMany();
  await prisma.user.deleteMany();

  const password = await bcrypt.hash('password123', 10);

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

  await prisma.job.create({
    data: {
      title: 'Logo Design for Startup',
      description: 'Need a modern logo for a tech startup.',
      status: JobStatus.IN_PROGRESS,
      serviceId: services[0].id,
      clientId: clients[0].id,
      freelancerId: freelancers[0].id,
    },
  });

  await prisma.job.create({
    data: {
      title: 'SEO for E-commerce',
      description: 'Optimize SEO for online shop.',
      status: JobStatus.PENDING,
      serviceId: services[2].id,
      clientId: clients[1].id,
      freelancerId: freelancers[1].id,
    },
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
