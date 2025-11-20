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

  const admin = await prisma.user.create({
    data: {
      email: 'admin@freetask.local',
      name: 'Admin Demo',
      password,
      role: UserRole.ADMIN,
    },
  });

  console.log('Created admin:', admin.email);

  const clientProfiles = [
    { email: 'aisyah.client@freetask.local', name: 'Aisyah Karim' },
    { email: 'danial.client@freetask.local', name: 'Danial Rahman' },
    { email: 'suriati.client@freetask.local', name: 'Suriati Musa' },
    { email: 'faiz.client@freetask.local', name: 'Faiz Hazim' },
  ];

  const freelancerProfiles = [
    { email: 'amira.freelancer@freetask.local', name: 'Amira Nordin', skills: ['Logo Design', 'Branding'] },
    { email: 'hazim.freelancer@freetask.local', name: 'Hazim Latif', skills: ['Copywriting', 'Content'] },
    { email: 'izzah.freelancer@freetask.local', name: 'Izzah Fauzi', skills: ['Web Development', 'UI/UX'] },
    { email: 'danial.freelancer@freetask.local', name: 'Danial Farid', skills: ['Photography', 'Editing'] },
  ];

  const clients = await Promise.all(
    clientProfiles.map((profile) =>
      prisma.user.create({
        data: {
          email: profile.email,
          name: profile.name,
          password,
          role: UserRole.CLIENT,
        },
      }),
    ),
  );

  const freelancers = await Promise.all(
    freelancerProfiles.map((profile) =>
      prisma.user.create({
        data: {
          email: profile.email,
          name: profile.name,
          password,
          role: UserRole.FREELANCER,
          skills: profile.skills,
        },
      }),
    ),
  );

  const servicesData = [
    {
      title: 'Logo Design Sprint',
      description: 'Konsep logo moden dengan 3 iterasi revisi.',
      price: new Prisma.Decimal(140),
      category: 'Design',
      freelancerId: freelancers[0].id,
    },
    {
      title: 'Brand Style Guide',
      description: 'Manual jenama lengkap dengan tipografi dan palet warna.',
      price: new Prisma.Decimal(150),
      category: 'Design',
      freelancerId: freelancers[0].id,
    },
    {
      title: 'Social Media Copy Pack',
      description: '20 kapsyen media sosial siap dengan CTA.',
      price: new Prisma.Decimal(90),
      category: 'Marketing',
      freelancerId: freelancers[1].id,
    },
    {
      title: 'Blog Post Premium',
      description: 'Artikel 1200 patah perkataan mesra SEO.',
      price: new Prisma.Decimal(120),
      category: 'Content',
      freelancerId: freelancers[1].id,
    },
    {
      title: 'Landing Page Next.js',
      description: 'Laman pendaratan pantas dengan integrasi analytics asas.',
      price: new Prisma.Decimal(150),
      category: 'Development',
      freelancerId: freelancers[2].id,
    },
    {
      title: 'UI/UX Audit',
      description: 'Analisis pengalaman pengguna dengan cadangan pantas.',
      price: new Prisma.Decimal(85),
      category: 'UI/UX',
      freelancerId: freelancers[2].id,
    },
    {
      title: 'Product Photoshoot',
      description: '10 gambar produk beresolusi tinggi.',
      price: new Prisma.Decimal(130),
      category: 'Photography',
      freelancerId: freelancers[3].id,
    },
    {
      title: 'Event Coverage 2 Jam',
      description: 'Fotografi acara ringkas beserta suntingan asas.',
      price: new Prisma.Decimal(110),
      category: 'Photography',
      freelancerId: freelancers[3].id,
    },
    {
      title: 'Business Card Design',
      description: 'Reka bentuk kad perniagaan depan belakang.',
      price: new Prisma.Decimal(40),
      category: 'Print',
      freelancerId: freelancers[0].id,
    },
    {
      title: 'Cleaning Service - Apartment',
      description: 'Pembersihan menyeluruh unit apartmen sederhana.',
      price: new Prisma.Decimal(75),
      category: 'Cleaning',
      freelancerId: freelancers[3].id,
    },
    {
      title: 'Aircond Service & Cleaning',
      description: 'Servis penyaman udara termasuk cucian kimia.',
      price: new Prisma.Decimal(95),
      category: 'Repair',
      freelancerId: freelancers[2].id,
    },
    {
      title: 'Resume & LinkedIn Makeover',
      description: 'Penulisan semula resume profesional dan profil LinkedIn.',
      price: new Prisma.Decimal(65),
      category: 'Career',
      freelancerId: freelancers[1].id,
    },
  ];

  const services = await Promise.all(
    servicesData.map((service) =>
      prisma.service.create({
        data: service,
      }),
    ),
  );

  const jobs = await Promise.all([
    prisma.job.create({
      data: {
        title: 'Kemaskini logo aplikasi fintech',
        description: 'Logo lebih ringkas dengan warna neon.',
        status: JobStatus.COMPLETED,
        amount: new Prisma.Decimal(145),
        serviceId: services[0].id,
        clientId: clients[0].id,
        freelancerId: services[0].freelancerId,
      },
    }),
    prisma.job.create({
      data: {
        title: 'Pandu gaya jenama untuk pelancaran Q4',
        description: 'Dokumen rujukan visual dan tone of voice.',
        status: JobStatus.COMPLETED,
        amount: new Prisma.Decimal(150),
        serviceId: services[1].id,
        clientId: clients[1].id,
        freelancerId: services[1].freelancerId,
      },
    }),
    prisma.job.create({
      data: {
        title: 'Kapsyen media sosial Ramadan',
        description: '20 kapsyen dengan tema promosi Ramadan.',
        status: JobStatus.IN_PROGRESS,
        amount: new Prisma.Decimal(95),
        serviceId: services[2].id,
        clientId: clients[2].id,
        freelancerId: services[2].freelancerId,
      },
    }),
    prisma.job.create({
      data: {
        title: 'Audit UI/UX aplikasi tempahan',
        description: 'Semak flow utama dan beri cadangan pantas.',
        status: JobStatus.IN_PROGRESS,
        amount: new Prisma.Decimal(90),
        serviceId: services[5].id,
        clientId: clients[0].id,
        freelancerId: services[5].freelancerId,
      },
    }),
    prisma.job.create({
      data: {
        title: 'Photoshoot produk minuman baharu',
        description: 'Fokus pada pencahayaan natural.',
        status: JobStatus.DISPUTED,
        disputeReason: 'Hasil tidak selari dengan moodboard.',
        amount: new Prisma.Decimal(130),
        serviceId: services[6].id,
        clientId: clients[3].id,
        freelancerId: services[6].freelancerId,
      },
    }),
    prisma.job.create({
      data: {
        title: 'Servis aircond pejabat',
        description: '3 unit perlu diservis dan dicuci.',
        status: JobStatus.DISPUTED,
        disputeReason: 'Kerja tertangguh melebihi janji.',
        amount: new Prisma.Decimal(95),
        serviceId: services[10].id,
        clientId: clients[1].id,
        freelancerId: services[10].freelancerId,
      },
    }),
    prisma.job.create({
      data: {
        title: 'Reka kad perniagaan premium',
        description: 'Guna kertas tekstur, kemasan emas.',
        status: JobStatus.PENDING,
        amount: new Prisma.Decimal(55),
        serviceId: services[8].id,
        clientId: clients[2].id,
        freelancerId: services[8].freelancerId,
      },
    }),
  ]);

  const [completedOne, completedTwo, inProgressOne, inProgressTwo, disputeOne, disputeTwo] = jobs;

  await prisma.chatMessage.createMany({
    data: [
      {
        content: 'Hi, saya dah mula rangka logo baharu. Ada preferensi font?',
        jobId: completedOne.id,
        senderId: completedOne.freelancerId,
      },
      {
        content: 'Saya suka Sans Serif. Warna utama kekalkan neon hijau.',
        jobId: completedOne.id,
        senderId: completedOne.clientId,
      },
      {
        content: 'Noted, konsep pertama siap esok pagi ya.',
        jobId: completedOne.id,
        senderId: completedOne.freelancerId,
      },
      {
        content: 'Boleh tambah CTA untuk slot sahur?',
        jobId: inProgressOne.id,
        senderId: inProgressOne.clientId,
      },
      {
        content: 'Baik, saya akan tambah 3 variasi CTA.',
        jobId: inProgressOne.id,
        senderId: inProgressOne.freelancerId,
      },
      {
        content: 'Kenapa shoot nampak terlalu gelap?',
        jobId: disputeOne.id,
        senderId: disputeOne.clientId,
      },
      {
        content: 'Saya boleh buat re-shoot dengan lampu tambahan petang ini.',
        jobId: disputeOne.id,
        senderId: disputeOne.freelancerId,
      },
      {
        content: 'Tekanan aircond tidak stabil, perlu tukar filter.',
        jobId: disputeTwo.id,
        senderId: disputeTwo.freelancerId,
      },
      {
        content: 'Mohon siapkan selewatnya petang ini, pejabat panas.',
        jobId: disputeTwo.id,
        senderId: disputeTwo.clientId,
      },
    ],
  });

  await prisma.review.createMany({
    data: [
      {
        rating: 5,
        comment: 'Hasil logo sangat kemas dan profesional.',
        jobId: completedOne.id,
        reviewerId: completedOne.clientId,
        revieweeId: completedOne.freelancerId,
      },
      {
        rating: 4,
        comment: 'Dokumen style guide jelas dan mudah diikut.',
        jobId: completedTwo.id,
        reviewerId: completedTwo.clientId,
        revieweeId: completedTwo.freelancerId,
      },
    ],
  });

  await prisma.notification.createMany({
    data: [
      {
        userId: completedOne.freelancerId,
        type: 'JOB_CREATED',
        title: 'Job baharu ditempah',
        body: `${clients[0].name} menempah ${services[0].title}.`,
        metadata: { jobId: completedOne.id, serviceId: services[0].id },
      },
      {
        userId: completedOne.clientId,
        type: 'JOB_UPDATED',
        title: 'Status job dikemas kini',
        body: `${services[0].title} telah diselesaikan.`,
        metadata: { jobId: completedOne.id, status: completedOne.status },
      },
      {
        userId: disputeOne.clientId,
        type: 'JOB_STATUS_UPDATED',
        title: 'Dispute dibuka',
        body: `Job ${disputeOne.title} kini dalam dispute.`,
        metadata: { jobId: disputeOne.id, status: disputeOne.status },
      },
      {
        userId: disputeTwo.clientId,
        type: 'JOB_STATUS_UPDATED',
        title: 'Dispute dibuka',
        body: `Job ${disputeTwo.title} kini dalam dispute.`,
        metadata: { jobId: disputeTwo.id, status: disputeTwo.status },
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
