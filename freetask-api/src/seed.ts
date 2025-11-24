import { PrismaClient, UserRole, JobStatus, Prisma } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function upsertUser(
  email: string,
  name: string,
  password: string,
  role: UserRole,
) {
  return prisma.user.upsert({
    where: { email },
    update: { name, password, role },
    create: { email, name, password, role },
  });
}

async function upsertService(
  title: string,
  description: string,
  price: number,
  category: string,
  freelancerId: number,
) {
  const existing = await prisma.service.findFirst({
    where: { title, freelancerId },
  });

  if (existing) {
    return existing;
  }

  return prisma.service.create({
    data: {
      title,
      description,
      price: new Prisma.Decimal(price),
      category,
      freelancerId,
    },
  });
}

async function upsertJob(
  title: string,
  description: string,
  status: JobStatus,
  amount: number,
  serviceId: number,
  clientId: number,
  freelancerId: number,
  disputeReason?: string,
) {
  const existing = await prisma.job.findFirst({
    where: { title, clientId, freelancerId },
  });

  if (existing) {
    return existing;
  }

  return prisma.job.create({
    data: {
      title,
      description,
      status,
      amount: new Prisma.Decimal(amount),
      serviceId,
      clientId,
      freelancerId,
      disputeReason: disputeReason ?? null,
    },
  });
}

async function main() {
  const force = process.env.SEED_FORCE === 'true';
  const reset = process.env.SEED_RESET === 'true';
  const isProd = process.env.NODE_ENV === 'production';
  const existingUsers = await prisma.user.count();

  const allowDevAutoSeed = !force && !isProd && existingUsers === 0;

  if (force) {
    console.warn('⚠️  SEED_FORCE enabled: existing data may be overwritten.');
  }

  if (!force && !allowDevAutoSeed) {
    const message =
      '❌ Seed blocked: database already has data. Re-run with SEED_FORCE=true npm run seed, or SEED_RESET=true npm run seed to wipe demo tables first.';
    console.error(message);
    throw new Error(message);
  }

  if (allowDevAutoSeed) {
    console.info('ℹ️  Auto-seeding empty development database (set SEED_FORCE=true to override).');
  }

  if (reset) {
    console.warn('⚠️  Destructive seed enabled: existing data will be wiped.');
    // Delete dependent tables first to avoid FK constraint errors
    await prisma.escrow.deleteMany();
    await prisma.session.deleteMany();
    await prisma.review.deleteMany();
    await prisma.chatMessage.deleteMany();
    await prisma.job.deleteMany();
    await prisma.service.deleteMany();
    await prisma.user.deleteMany();
  } else {
    console.info('Running in non-destructive mode (SEED_RESET=false). Existing data is preserved.');
  }

  const rawPassword = 'Password123!';
  const password = await bcrypt.hash(rawPassword, 10);

  const freelancers = await Promise.all([
    upsertUser('freelancer1@example.com', 'Freelancer One', password, UserRole.FREELANCER),
    upsertUser('freelancer2@example.com', 'Freelancer Two', password, UserRole.FREELANCER),
    upsertUser('freelancer@example.com', 'Freelancer QA', password, UserRole.FREELANCER),
  ]);

  const clients = await Promise.all([
    upsertUser('client1@example.com', 'Client One', password, UserRole.CLIENT),
    upsertUser('client2@example.com', 'Client Two', password, UserRole.CLIENT),
    upsertUser('client@example.com', 'Client QA', password, UserRole.CLIENT),
  ]);

  const admin = await upsertUser('admin@example.com', 'Admin User', password, UserRole.ADMIN);

  const services = await Promise.all([
    upsertService('Logo Design', 'Professional logo design service.', 150, 'Design', freelancers[0].id),
    upsertService(
      'Website Development',
      'Full-stack website development.',
      1200,
      'Development',
      freelancers[0].id,
    ),
    upsertService(
      'SEO Optimization',
      'Improve your search engine rankings.',
      400,
      'Marketing',
      freelancers[1].id,
    ),
    upsertService(
      'Social Media Management',
      'Grow and manage your social media presence.',
      300,
      'Marketing',
      freelancers[1].id,
    ),
  ]);

  const jobs = await Promise.all([
    upsertJob(
      'Logo Design for Startup',
      'Need a modern logo for a tech startup.',
      JobStatus.PENDING,
      200,
      services[0].id,
      clients[0].id,
      freelancers[0].id,
    ),
    upsertJob(
      'Landing Page Build',
      'Simple responsive landing page.',
      JobStatus.ACCEPTED,
      750,
      services[1].id,
      clients[1].id,
      freelancers[0].id,
    ),
    upsertJob(
      'SEO for E-commerce',
      'Optimize SEO for online shop.',
      JobStatus.IN_PROGRESS,
      600,
      services[2].id,
      clients[1].id,
      freelancers[1].id,
    ),
    upsertJob(
      'Social Campaign',
      'Two-week campaign management.',
      JobStatus.CANCELLED,
      280,
      services[3].id,
      clients[0].id,
      freelancers[1].id,
    ),
    upsertJob(
      'Storefront redesign',
      'Completed storefront redesign.',
      JobStatus.COMPLETED,
      1200,
      services[1].id,
      clients[0].id,
      freelancers[0].id,
    ),
    upsertJob(
      'Logo tweaks round',
      'Rejected after initial consultation.',
      JobStatus.REJECTED,
      150,
      services[0].id,
      clients[1].id,
      freelancers[1].id,
    ),
    upsertJob(
      'E-commerce audit',
      'Client disputed deliverables.',
      JobStatus.DISPUTED,
      450,
      services[2].id,
      clients[0].id,
      freelancers[1].id,
      'Report missing agreed benchmarks.',
    ),
    upsertJob(
      'Brand identity package',
      'Admin review needed - payment held.',
      JobStatus.ACCEPTED,
      850,
      services[0].id,
      clients[1].id,
      freelancers[0].id,
    ),
  ]);

  await Promise.all(
    jobs.map((job) =>
      prisma.$executeRaw`
        INSERT INTO "Escrow" ("jobId", status, amount, "createdAt", "updatedAt")
        VALUES (${job.id}, 'PENDING', ${job.amount.toString()}, NOW(), NOW())
        ON CONFLICT ("jobId") DO NOTHING
      `,
    ),
  );

  // Set specific escrow statuses for admin testing
  if (jobs[6]) {
    await prisma.$executeRaw`
      UPDATE "Escrow" SET status = 'DISPUTED', "updatedAt" = NOW()
      WHERE "jobId" = ${jobs[6].id}
    `;
  }
  if (jobs[7]) {
    await prisma.$executeRaw`
      UPDATE "Escrow" SET status = 'HELD', "updatedAt" = NOW()
      WHERE "jobId" = ${jobs[7].id}
    `;
  }

  await prisma.review.upsert({
    where: { jobId: jobs[4].id },
    update: {
      rating: 5,
      comment: 'Great work delivered on time!',
      reviewerId: clients[0].id,
      revieweeId: freelancers[0].id,
    },
    create: {
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

  console.log('✅ Seed data created successfully');
  console.log('\n📋 Demo Credentials (all use password: Password123!)');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('  Role       | Email');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`  ADMIN      | ${admin.email}`);
  clients.forEach((user) => {
    console.log(`  CLIENT     | ${user.email}`);
  });
  freelancers.forEach((user) => {
    console.log(`  FREELANCER | ${user.email}`);
  });
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`\n🔑 Password for all users: ${rawPassword}`);
  console.log('\n💡 Tip: Use admin@example.com to test escrow hold/release/refund actions.');
  console.log('    Jobs with HELD/DISPUTED escrow status have been seeded for testing.\n');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
